cimport numpy
import numpy

# unfortunately cython does not allow multiple inheritance
# therefor we cannot also use CyConfig as a base class
# and must use composition here

cdef class CyEventExt(CyEvent):
  """
  Class internal to the fcio library. Do not allocate directly, must be created by using `fcio_open` or 
  FCIO.open().
  Exposes the fcio_event struct fields from the fcio.c library.
  All fields are exposes as numpy scalars or arrays with their corresponsing datatype and size.

  Additionally CyEventExt offers some extension to the basic CyEvent attributes. These represent either
  convenient names values in some field, or offer some required pre-calculation.

  All CyEvent attributes are still available.
  """

  cdef numpy.ndarray _card_addresses
  cdef numpy.ndarray _card_channels

  cdef numpy.int32_t _utc_unix_sec
  cdef numpy.int32_t _utc_unix_nsec
  cdef numpy.float64_t _utc_unix

  cdef numpy.int32_t _run_time_sec
  cdef numpy.int32_t _run_time_nsec
  cdef numpy.float64_t _run_time

  cdef int _check_max_ticks

  cdef numpy.ndarray _tracemap

  # def __cinit__(self):
  def __cinit__(self, fcio : CyFCIO):

    cdef unsigned int[:] tracemap_view = self.config_ptr.tracemap
    self._tracemap = numpy.ndarray(shape=(self.maxtraces,), dtype=numpy.uint32, offset=0, buffer=tracemap_view)

    self._card_addresses = self._tracemap >> 16 # upper 16bit
    self._card_channels = self._tracemap % (1 << 16) # lower 16bit

    self._check_max_ticks = 1 if self.config_ptr.gps in (1,5) else 0

  cdef update(self):
    CyEvent.update(self)

    # Check for timestamp consistency
    cdef expected_max_ticks = 249999999
    if self._check_max_ticks != 0:
      if self.timestamp[3] != expected_max_ticks:
        # replace with logging
        print(f"Max Ticks field for event {self.timestamp[0]} pps {self.timestamp[1]} is not {expected_max_ticks} but {self.timestamp[3]}.")
        # raise Exception(f"Max Ticks field for event {self.timestamp[0]} pps {self.timestamp[1]} is not {expected_max_ticks} but {self.timestamp[3]}.")

    # update time information
    self._run_time_sec = self.timestamp[1]
    self._run_time_nsec = 4 * self.timestamp[2]
    self._utc_unix_sec = self._run_time_sec
    self._utc_unix_nsec = self._run_time_nsec

    if self.config_ptr.gps != 0:
      self._utc_unix_sec += self.timeoffset[2]
    else:
      self._utc_unix_sec += self.timeoffset[0]
      self._utc_unix_nsec += 1000 * self.timeoffset[1]

      while self._utc_unix_nsec >= 1000000000L:
        self._utc_unix_sec += 1
        self._utc_unix_nsec -= 1000000000L
    
    self._utc_unix = self._utc_unix_sec + 1.0e-9 * self._utc_unix_nsec

    # TODO correct for the delta t between reset of counters and actually enabling the trigger
    self._run_time = self._run_time_sec + 1.0e-9 * self._run_time_nsec

  cpdef trace_indices(self, trace_idx = None, trace_map = None, warn_unmapped = False):
    import numbers

    cdef set trace_indices = set()
    cdef unsigned int tracemap_to_check

    # convert
    if trace_idx != None:
      if isinstance(trace_idx, numbers.Integral):
        trace_idx = [trace_idx]

      if numpy.iterable(trace_idx):
        for idx in trace_idx:
          if isinstance(idx, numbers.Integral):
            if idx >= 0 or idx < self.maxtraces:
              trace_indices.add(idx)
            else:
              raise KeyError(f"trace_idx {idx} not found in mapped channels.")
          else:
            raise ValueError(f"trace_idx {trace_idx} is not of integer type.")
      else:
        raise ValueError(f"{trace_idx} is neither an integer nor an iterable.")

    if trace_map != None:
      if not numpy.iterable(trace_map):
        trace_map = [trace_map]

      if numpy.iterable(trace_map):
        for card_to_map in trace_map:
          if isinstance(card_to_map, numbers.Integral):
            tracemap_to_check = card_to_map
          elif isinstance(card_to_map[0], numbers.Integral) and isinstance(card_to_map[1], numbers.Integral):
            tracemap_to_check = (card_to_map[0] << 16) + card_to_map[1]
          else:
            raise ValueError(f"trace_map {card_to_map} is neither of integer type or a sequence if minimum two integers.")

          # stupid search
          for i, tracemap_entry in enumerate(self._tracemap):
            if tracemap_entry == tracemap_to_check:
              trace_indices.add(i)
              break
            elif warn_unmapped and tracemap_entry == 0:
              raise KeyError(f"trace_map {hex(tracemap_to_check)} not found in mapped channels.")
    return numpy.array(sorted(trace_indices))

  @property
  def fpga_baseline(self):
    """
    1D array.
    shape is (<total number of mapped trace>,)
    Contains the fpga baseline values.
    """
    return self.theader[self._np_trace_list,0] / self.config_ptr.blprecision

  @property
  def fpga_energy(self):
    """
    1D array.
    shape is (<total number of mapped trace>,)
    Contains the fpga energy values.
    """
    if self.config_ptr.adcbits == 12: #250MHz
      return self.config_ptr.sumlength / self.config_ptr.blprecision * (self.theader[self._np_trace_list,1] - self.theader[self._np_trace_list,0])
    elif self.config_ptr.adcbits == 16: #62.5MHz
      return self.theader[self._np_trace_list,1]

  @property
  def card_address(self):
    """
    List of corresponding MAC addresses of the FADC Card per channel.
    Display in human readable form as hex(car_address[index])
    """
    return self._card_addresses[self._np_trace_list]

  @property
  def card_channel(self):
    """
    List of input RJ45 Jacks of the FADC Card per channel.
    Must be within [0,5] for 16-bit firmware and [0,23] for 12-bit firmware.
    """
    return self._card_channels[self._np_trace_list]

  @property
  def eventsamples(self):
    """
    The number of samples of each waveform.
    This parameter is taken from the Config Record and exposed here for convenience.
    """
    return numpy.int32(self.config_ptr.eventsamples)

  @property
  def eventnumber(self):
    """
    The event counter from the Top Master Card of this event for FCIOEvent records,
    and the event counter from the corresponding FADC Card for FCIOSparseEvent records.
    """
    return numpy.int32(self.timestamp[0])

  @property
  def gps(self):
    """
    The maximum time difference between fpga pps and readout server second.
    If no external clock is used, this parameter is 0.
    """
    return numpy.int32(self.config_ptr.gps)

  @property
  def run_time_sec(self):
    """
    The number of seconds since run start.
    """
    return self._run_time_sec

  @property
  def run_time_nsec(self):
    """
    The number of nanoseconds since last second (run_time_sec).
    """
    return self._run_time_nsec

  @property
  def run_time(self):
    """
    The time since run start in seconds as floating point, with decimals extracted from run_time_nsec.
    """
    return self._run_time

  @property
  def utc_unix_sec(self):
    """
    The number of UTC seconds since beginning of unix time (first of January 1970).
    """
    return self._utc_unix_sec

  @property
  def utc_unix_nsec(self):
    """
    The number of nanoseconds since last utc_unix_sec.
    """
    return self._utc_unix_nsec

  @property
  def utc_unix(self):
    """
    The time (UTC) since beginning of unix time (first of January 1970) as floating point.
    Be aware that float64 on your machine probably doesn't allow for better than microsecond precision.
    """
    return self._utc_unix

  @property
  def trace(self):
    """
    2D array containing the waveforms.
    shape is (<total number of traces in this event>,<number of samples>).
    See trace_list to get the correct trace_index or card_address / card_channel attributes.
    """
    return self._np_trace[self._np_trace_list]

  @property
  def theader(self):
    """
    2D array of the waveforms headers containing the [0]fpga baseline and [1] fpga energy.
    shape is (<total number of traces in this event>,<2>)
    """
    return self._np_theader[self._np_trace_list]

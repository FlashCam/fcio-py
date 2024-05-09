cimport numpy
import numpy

import sys

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
  cdef numpy.ndarray _tracemap
  cdef numpy.ndarray _card_addresses
  cdef numpy.ndarray _card_channels

  cdef int _num_channels_per_card
  
  cdef numpy.int64_t _utc_unix_ns
  cdef numpy.float64_t _utc_unix
  
  cdef numpy.int64_t _fpga_time_ns

  cdef numpy.int32_t _allowed_gps_error_ns
  
  cdef numpy.ndarray _start_time_ns
  cdef numpy.ndarray _cur_dead_time_ns
  cdef numpy.ndarray _total_dead_time_ns

  cdef DeadIntervalBuffer _dead_interval_buffer

  def __cinit__(self, fcio : CyFCIO):

    self._dead_interval_buffer = DeadIntervalBuffer()

    cdef unsigned int[::1] tracemap_view = self.config_ptr.tracemap
    self._tracemap = numpy.ndarray(shape=(self.maxtraces,), dtype=numpy.uint32, offset=0, buffer=tracemap_view)

    self._card_addresses = self._tracemap >> 16 # upper 16bit
    self._card_channels = self._tracemap % (1 << 16) # lower 16bit

    self._start_time_ns = numpy.zeros(shape=(self.config_ptr.adcs,),dtype=numpy.int64)
    self._start_time_ns[:] = -1

    self._cur_dead_time_ns = numpy.zeros(shape=(self.config_ptr.adcs,),dtype=numpy.int64)
    self._total_dead_time_ns = numpy.zeros(shape=(self.config_ptr.adcs,),dtype=numpy.int64)

    if self.config_ptr.adcbits == 12:
      self._num_channels_per_card = 24
    elif self.config_ptr.adcbits == 16:
      self._num_channels_per_card = 6

    self._allowed_gps_error_ns = self.config_ptr.gps

  cdef update(self):
    
    ## calculate timestamps in nanoseconds and update float properties

    # update current pps/clk counters
    cdef long _daq_synchronized_timestamp_ns = (1000000000L * self.timestamp[1] + 4 * self.timestamp[2])
    self._fpga_time_ns = _daq_synchronized_timestamp_ns

    # update absolute time information
    if self.config_ptr.gps != 0:
      # we have external clock (likely from a timeserver or gps clock)
      self._utc_unix_ns = _daq_synchronized_timestamp_ns + self.timeoffset[2] * 1000000000L
    else:
      # synchronization via server clock (likely from NTP server)
      self._utc_unix_ns = _daq_synchronized_timestamp_ns + 1000000000L * self.timeoffset[0] + 1000 * self.timeoffset[1]
    
    self._utc_unix = self._utc_unix_ns / 1.0e9

    cdef int _expected_max_ticks = 249999999
    cdef int _current_clock_offset = abs(self.timestamp[3] - _expected_max_ticks) * 4  
    # if _current_clock_offset > self._allowed_gps_error_ns:
    #   print(f"WARNING fcio: max_ticks of last pps cycle {self.timestamp[3]} with { _current_clock_offset } > {self._allowed_gps_error_ns}",file=sys.stderr)

    # default deadtimes are the same for all channels
    # we update them with the same values
    # only dr_start is used to track progress
    cdef int dr_start = 0
    cdef int dr_end = self.config_ptr.adcs

    # for daqmode 12, each card has it's own eventnumbers, clock counters and deadregions
    # need to track them separately, but will do it on a channel list basis

    if self.event_ptr.type == 11:
      dr_start = self.event_ptr.deadregion[5]
      dr_end = self.event_ptr.deadregion[5] + self.event_ptr.deadregion[6]

    cdef long _dead_interval_start_ns = self.event_ptr.deadregion[0] * 1000000000L + self.event_ptr.deadregion[1] * 4 
    cdef long _dead_interval_stop_ns = self.event_ptr.deadregion[2] * 1000000000L + self.event_ptr.deadregion[3] * 4
    cdef long _dead_interval_ns = _dead_interval_stop_ns - _dead_interval_start_ns

    if numpy.any(self._start_time_ns[dr_start : dr_end] == -1):
      # start times not set yet
      if _dead_interval_start_ns == 0 and _dead_interval_stop_ns > 0:
        # if only start is zero, it's daqmode 12 per card and we can estimate the trigger enable timestamp from that
        self._start_time_ns[dr_start : dr_end] = _dead_interval_stop_ns
      elif _dead_interval_start_ns == 0 and _dead_interval_stop_ns == 0:
        self._start_time_ns[dr_start : dr_end] = _daq_synchronized_timestamp_ns

    if _dead_interval_start_ns > 0:
      # if first event contains start and stop stamps, it's a true dead interval between events, add it
      self._dead_interval_buffer.add(_dead_interval_start_ns, _dead_interval_stop_ns, self.event_ptr.deadregion[5], self.event_ptr.deadregion[6])

    self._cur_dead_time_ns[dr_start : dr_end] = 0
    while self._dead_interval_buffer.is_before(_daq_synchronized_timestamp_ns, self.event_ptr.deadregion[5], self.event_ptr.deadregion[6]):
      self._cur_dead_time_ns[dr_start : dr_end] = self._dead_interval_buffer.read(self.event_ptr.deadregion[5], self.event_ptr.deadregion[6])
      self._total_dead_time_ns[dr_start : dr_end] += self._cur_dead_time_ns[dr_start : dr_end]

  @property
  def fpga_baseline(self):
    """
    1D array.
    shape is (<total number of mapped trace>,)
    Contains the fpga baseline values.
    """
    return self.theader[self.trace_list,0] / self.config_ptr.blprecision

  @property
  def fpga_energy(self):
    """
    1D array.
    shape is (<total number of mapped trace>,)
    Contains the fpga energy values.
    """
    if self.config_ptr.adcbits == 12: #250MHz
      return self.config_ptr.sumlength / self.config_ptr.blprecision * (self.theader[self.trace_list,1] - self.theader[self.trace_list,0])
    elif self.config_ptr.adcbits == 16: #62.5MHz
      return self.theader[self.trace_list,1]
  
  @property
  def cur_dead_time_ns(self):
    """
    The dead time since the last triggered event in nanoseconds
    """
    return self._cur_dead_time_ns[self.trace_list]

  @property
  def start_time_ns(self):
    return self._start_time_ns[self.trace_list]

  @property
  def dead_time_ns(self):
    """
    The total dead time since the last DAQ reset (start of run) in nanoseconds
    """
    return self._total_dead_time_ns[self.trace_list]

  @property
  def card_address(self):
    """
    List of corresponding MAC addresses of the FADC Card per channel.
    Display in human readable form as hex(car_address[index])
    """
    return self._card_addresses[self.trace_list]

  @property
  def card_channel(self):
    """
    List of input RJ45 Jacks of the FADC Card per channel.
    Must be within [0,5] for 16-bit firmware and [0,23] for 12-bit firmware.
    """
    return self._card_channels[self.trace_list]

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
  def fpga_time_ns(self):
    """
    The number of nanoseconds since daq reset.
    """
    return self._fpga_time_ns

  @property
  def utc_unix_ns(self):
    """
    The number of nanoseconds since 1970 (UTC unix timestamps).
    """
    return self._utc_unix_ns

  @property
  def utc_unix(self):
    """
    utc_unix_ns in seconds as float64.
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
    return self._np_trace[self.trace_list]

  @property
  def theader(self):
    """
    2D array of the waveforms headers containing the [0]fpga baseline and [1] fpga energy.
    shape is (<total number of traces in this event>,<2>)
    """
    return self._np_theader[self.trace_list]

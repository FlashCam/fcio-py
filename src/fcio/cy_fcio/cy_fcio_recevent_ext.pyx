cimport numpy
import numpy

import sys

import numbers

cdef class CyRecEventExt(CyRecEvent):
  """
  Class internal to the fcio library. Do not allocate directly, must be created by using `fcio_open` or 
  FCIO.open().
  Exposes the fcio_event struct fields from the fcio.c library.
  All fields are exposes as numpy scalars or arrays with their corresponsing datatype and size.

  Additionally CyRecEventExt offers some extension to the basic CyEvent attributes. These represent either
  convenient names values in some field, or offer some required pre-calculation.

  All CyEvent attributes are still available.
  """

  cdef numpy.ndarray _card_addresses
  cdef numpy.ndarray _card_channels

  
  cdef numpy.int64_t _utc_unix_ns
  cdef numpy.float64_t _utc_unix
  
  cdef numpy.int64_t _run_time_ns
  cdef numpy.float64_t _run_time

  cdef numpy.int32_t _wait_for_first_event
  
  cdef numpy.int64_t _start_time_ns

  cdef numpy.ndarray _dead_time_ns
  cdef numpy.ndarray _total_dead_time_ns

  cdef numpy.int32_t _allowed_gps_error_ns

  cdef int _current_dead_time_end_pps
  cdef int _current_dead_time_end_ticks

  cdef numpy.ndarray _tracemap

  cdef numpy.ndarray _np_channel_pulses_start
  cdef numpy.ndarray _np_channel_pulses_stop

  def __cinit__(self, fcio : CyFCIO):

    cdef unsigned int[::1] tracemap_view = self.config_ptr.tracemap
    self._tracemap = numpy.ndarray(shape=(self.maxtraces,), dtype=numpy.uint32, offset=0, buffer=tracemap_view)

    self._card_addresses = self._tracemap >> 16 # upper 16bit
    self._card_channels = self._tracemap % (1 << 16) # lower 16bit

    self._dead_time_ns = numpy.zeros(shape=(self.config_ptr.adcs,),dtype=numpy.int64)
    self._total_dead_time_ns = numpy.zeros(shape=(self.config_ptr.adcs,),dtype=numpy.int64)

    self._allowed_gps_error_ns = self.config_ptr.gps
    self._wait_for_first_event = True
    self._start_time_ns = 0

  cdef update(self):

    cdef numpy.int64_t _event_deadtime

    if self._wait_for_first_event:
      self._start_time_ns = self.recevent_ptr.deadregion[2] * 1000000000L + self.recevent_ptr.deadregion[3] * 4
      self._wait_for_first_event = False
    else:
      # determine if we have a new dead region end and update the counters
      if self._current_dead_time_end_pps != self.recevent_ptr.deadregion[2] or self._current_dead_time_end_ticks != self.recevent_ptr.deadregion[3]:
        _event_deadtime = (self.recevent_ptr.deadregion[2]-self.recevent_ptr.deadregion[0]) * 1000000000L + (self.recevent_ptr.deadregion[3]-self.recevent_ptr.deadregion[1]) * 4
        self._dead_time_ns[self.recevent_ptr.deadregion[5] : self.recevent_ptr.deadregion[5] + self.recevent_ptr.deadregion[6]] = _event_deadtime
        self._total_dead_time_ns[self.recevent_ptr.deadregion[5] : self.recevent_ptr.deadregion[5] + self.recevent_ptr.deadregion[6]] += _event_deadtime
      else:
        self._dead_time_ns[:] = 0
    
    cdef expected_max_ticks = 249999999
    
    cdef numpy.int64_t _current_clock_offset

    _current_clock_offset = abs(self.timestamp[3] - expected_max_ticks) * 4  
    
    if _current_clock_offset > self._allowed_gps_error_ns:
      print(f"WARNING fcio: max_ticks of last pps cycle {self.timestamp[3]} with { _current_clock_offset } > {self._allowed_gps_error_ns}",file=sys.stderr)

    cdef numpy.int64_t nanoseconds_since_daq_reset
    # store the current clock cycle information temporarily
    nanoseconds_since_daq_reset = (1000000000L * self.timestamp[1] + 4 * self.timestamp[2])

    # update relative time information, correct for time until the trigger was enabled in the system
    self._run_time_ns = nanoseconds_since_daq_reset - self._start_time_ns
    self._run_time = self._run_time_ns / 1000000000L

    # update absolute time information
    if self.config_ptr.gps != 0:
      self._utc_unix_ns = nanoseconds_since_daq_reset + self.timeoffset[2] * 1000000000L
    else:
      self._utc_unix_ns = nanoseconds_since_daq_reset + 1000000000L * self.timeoffset[0] + 1000 * self.timeoffset[1]
    
    self._utc_unix = self._utc_unix_ns / 1.0e-9
  
  @property
  def dead_time_ns(self):
    """
    The dead time since the last triggered event in nanoseconds
    """
    return self._dead_time_ns[self._np_trace_list]

  @property
  def total_dead_time_ns(self):
    """
    The total dead time since the last DAQ reset (start of run) in nanoseconds
    """
    return self._total_dead_time_ns[self._np_trace_list]

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
  def run_time_ns(self):
    """
    The number of nanoseconds since trigger enable.
    """
    return self._run_time_ns

  @property
  def run_time(self):
    """
    run_time_ns in seconds as float64.
    """
    return self._run_time

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
  def pulses(self):
    cdef int offset = 0
    cdef int npulses, i
    for i in range(self.maxtraces):
      npulses = self.recevent_ptr.channel_pulses[i]
      if npulses > 0:
        yield (i, 
          self._np_flags[offset:offset+npulses],
          self._np_times[offset:offset+npulses],
          self._np_amplitudes[offset:offset+npulses]
        )
        offset += npulses

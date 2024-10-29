from fcio_def cimport fcio_config

cimport numpy

cdef class FCIOExt:

  cdef fcio_config *_config_ptr
  cdef int* _timestamp
  cdef int* _timeoffset
  cdef int* _deadregion

  # derived from config
  cdef numpy.ndarray _tracemap
  cdef numpy.ndarray _card_addresses
  cdef numpy.ndarray _card_channels
  cdef int _num_channels_per_card
  cdef int _maxtraces

  # derived from event / recevent base information
  cdef numpy.int64_t _utc_unix_ns
  cdef numpy.float64_t _utc_unix

  cdef numpy.int64_t _fpga_time_ns

  cdef numpy.int32_t _allowed_gps_error_ns

  cdef numpy.ndarray _start_time_ns
  cdef numpy.ndarray _cur_dead_time_ns
  cdef numpy.ndarray _total_dead_time_ns

  cdef DeadIntervalBuffer _dead_interval_buffer

  cdef int _tag

  def __cinit__(self, fcio : FCIO):

    if isinstance(self, Event):
      self._timestamp = fcio._fcio_data.event.timestamp
      self._timeoffset = fcio._fcio_data.event.timeoffset
      self._deadregion = fcio._fcio_data.event.deadregion
    elif isinstance(self, RecEvent):
      self._timestamp = fcio._fcio_data.recevent.timestamp
      self._timeoffset = fcio._fcio_data.recevent.timeoffset
      self._deadregion = fcio._fcio_data.recevent.deadregion
    else:
      raise NotImplemented("FCIOExt does not implement an interface {type(self)}")

    self._config_ptr = &fcio._fcio_data.config

    self._dead_interval_buffer = DeadIntervalBuffer()

    # helper variables
    self._maxtraces = self._config_ptr.adcs + self._config_ptr.triggers

    cdef unsigned int[::1] tracemap_view = self._config_ptr.tracemap
    self._tracemap = numpy.ndarray(shape=(self._maxtraces,), dtype=numpy.uint32, offset=0, buffer=tracemap_view)

    self._card_addresses = self._tracemap >> 16 # upper 16bit
    self._card_channels = self._tracemap % (1 << 16) # lower 16bit

    self._start_time_ns = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)
    self._start_time_ns[:] = -1

    self._cur_dead_time_ns = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)
    self._total_dead_time_ns = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)

    if self._config_ptr.adcbits == 12:
      self._num_channels_per_card = 24
    elif self._config_ptr.adcbits == 16:
      self._num_channels_per_card = 6

    self._allowed_gps_error_ns = self._config_ptr.gps

  cdef update(self):

    # No const in cython :/
    cdef long long NS_PER_S = 1000000000
    cdef long long EXPECTED_MAX_TICKS = 249999999
    cdef long long NS_PER_TICK = 4

    # update current pps/clk counters
    cdef long long _daq_synchronized_timestamp_ns = (NS_PER_S * self._timestamp[1] + 4 * self._timestamp[2])
    self._fpga_time_ns = _daq_synchronized_timestamp_ns

    # update absolute time information
    if self._config_ptr.gps != 0:
      # we have an external clock (likely from a timeserver or gps clock)
      self._utc_unix_ns = _daq_synchronized_timestamp_ns + self._timeoffset[2] * NS_PER_S
    else:
      # synchronization via server clock (likely from NTP server)
      self._utc_unix_ns = _daq_synchronized_timestamp_ns + NS_PER_S * self._timeoffset[0] + 1000 * self._timeoffset[1]

    self._utc_unix = self._utc_unix_ns / NS_PER_S

    cdef int _current_clock_offset = abs(self._timestamp[3] - EXPECTED_MAX_TICKS) * NS_PER_TICK
    # if _current_clock_offset > self._allowed_gps_error_ns:
    #   print(f"WARNING fcio: max_ticks of last pps cycle {self.timestamp[3]} with { _current_clock_offset } > {self._allowed_gps_error_ns}",file=sys.stderr)

    # default deadtimes are the same for all channels
    # only dr_start is used to track progress
    cdef int dr_start = 0
    cdef int dr_end = self._config_ptr.adcs

    # for daqmode 12 (event.type 11), each card has it's own eventnumbers, clock counters and deadregions
    # need to track them separately, but will do it on a channel list basis

    if self.type == 11:
      dr_start = self._deadregion[5]
      dr_end = self._deadregion[5] + self._deadregion[6]

    cdef long long _dead_interval_start_ns = self._deadregion[0] * NS_PER_S + self._deadregion[1] * NS_PER_TICK
    cdef long long _dead_interval_stop_ns = self._deadregion[2] * NS_PER_S + self._deadregion[3] * NS_PER_TICK
    cdef long long _dead_interval_ns = _dead_interval_stop_ns - _dead_interval_start_ns

    if numpy.any(self._start_time_ns[dr_start : dr_end] == -1):
      # start times not set yet
      if _dead_interval_start_ns == 0 and _dead_interval_stop_ns > 0:
        # if only start is zero, it's daqmode 12 per card and we can estimate the trigger enable timestamp from that
        self._start_time_ns[dr_start : dr_end] = _dead_interval_stop_ns
      elif _dead_interval_start_ns == 0 and _dead_interval_stop_ns == 0:
        self._start_time_ns[dr_start : dr_end] = _daq_synchronized_timestamp_ns

    if _dead_interval_start_ns > 0:
      # if first event contains start and stop stamps, it's a true dead interval between events, add it
      self._dead_interval_buffer.add(_dead_interval_start_ns, _dead_interval_stop_ns, dr_start, dr_end)

    self._cur_dead_time_ns[dr_start : dr_end] = 0
    while self._dead_interval_buffer.is_before(_daq_synchronized_timestamp_ns, dr_start, dr_end):
      self._cur_dead_time_ns[dr_start : dr_end] = self._dead_interval_buffer.read(dr_start, dr_end)
      self._total_dead_time_ns[dr_start : dr_end] += self._cur_dead_time_ns[dr_start : dr_end]

  @property
  def cur_dead_time_ns(self):
    """
    The dead time since the last triggered event in nanoseconds.
    """
    return self._cur_dead_time_ns[self.trace_list]

  @property
  def start_time_ns(self):
    """
    Contains a best guess, array
    """
    return self._start_time_ns[self.trace_list]

  @property
  def dead_time_ns(self):
    """
    The total dead time since the last DAQ reset (start of run) in nanoseconds.
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
    return numpy.int32(self._config_ptr.eventsamples)

  @property
  def eventnumber(self):
    """
    The event counter from the Top Master Card of this event for FCIOEvent records,
    and the event counter from the corresponding FADC Card for FCIOSparseEvent records.
    """
    return numpy.int32(self._timestamp[0])

  @property
  def gps(self):
    """
    The maximum time difference between fpga pps and readout server second.
    If no external clock is used, this parameter is 0.
    """
    return numpy.int32(self._config_ptr.gps)

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
    Be aware that float64 on your machine probably doesn't allow for a precision better than microseconds.
    """
    return self._utc_unix

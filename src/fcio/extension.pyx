from .def_fcio cimport fcio_config

cimport numpy

cdef class FCIOHeaderExt:

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
  cdef numpy.int64_t _unix_time_utc_nsec
  cdef numpy.float64_t _unix_time_utc_sec

  cdef numpy.int64_t _fpga_time_nsec
  cdef numpy.float64_t _fpga_time_sec

  cdef numpy.int32_t _allowed_gps_error_nsec

  cdef numpy.ndarray _trigger_enable_time_nsec

  cdef numpy.ndarray _dead_interval_nsec
  cdef numpy.ndarray _dead_interval_sec

  cdef numpy.ndarray _dead_time_nsec
  cdef numpy.ndarray _dead_time_sec

  cdef numpy.ndarray _life_time_nsec
  cdef numpy.ndarray _life_time_sec

  cdef numpy.ndarray _run_time_nsec
  cdef numpy.ndarray _run_time_sec

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

    self._trigger_enable_time_nsec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)
    self._trigger_enable_time_nsec[:] = -1

    self._dead_interval_nsec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)
    self._dead_time_nsec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)
    self._dead_time_sec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.float64)

    self._run_time_nsec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)
    self._run_time_sec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.float64)

    self._life_time_nsec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.int64)
    self._life_time_sec = numpy.zeros(shape=(self._config_ptr.adcs,),dtype=numpy.float64)

    if self._config_ptr.adcbits == 12:
      self._num_channels_per_card = 24
    elif self._config_ptr.adcbits == 16:
      self._num_channels_per_card = 6

    self._allowed_gps_error_nsec = self._config_ptr.gps

  cdef update(self):

    # No const in cython :/
    cdef long long NSEC_PER_SEC = 1000000000
    cdef long long EXPECTED_MAX_TICKS = 249999999
    cdef long long NSEC_PER_TICK = 4

    # update current current fpga timestamp from pps/clk counters
    cdef long long _daq_synchronized_timestamp_nsec = (NSEC_PER_SEC * self._timestamp[1] + 4 * self._timestamp[2])
    self._fpga_time_nsec = _daq_synchronized_timestamp_nsec
    cdef long long _unix_start_time_nsec = 0

    # update absolute time information
    if self._config_ptr.gps != 0:
      # we have an external clock (likely from a timeserver or gps clock)
      self._unix_time_utc_nsec = _daq_synchronized_timestamp_nsec + self._timeoffset[2] * NSEC_PER_SEC
    else:
      # synchronization via server clock (likely from NTP server)
      self._unix_time_utc_nsec = _daq_synchronized_timestamp_nsec + NSEC_PER_SEC * self._timeoffset[0] + 1000 * self._timeoffset[1]

    # TODO: if required check clock stability
    # cdef int _current_clock_offset = abs(self._timestamp[3] - EXPECTED_MAX_TICKS) * NSEC_PER_TICK
    # if _current_clock_offset > self._allowed_gps_error_nsec:
    #   print(f"WARNING fcio: max_ticks of last pps cycle {self.timestamp[3]} with { _current_clock_offset } > {self._allowed_gps_error_nsec}",file=sys.stderr)

    # default dead intervals affect all channels
    # only dr_start is used to track progress
    cdef int dr_start = 0
    cdef int dr_end = self._config_ptr.adcs

    # for daqmode 12 (event.type 11), each card has it's own eventnumbers, clock counters and dead intervals

    if self.type == 11:
      dr_start = self._deadregion[5]
      dr_end = self._deadregion[5] + self._deadregion[6]

    cdef long long _dead_interval_start_nsec = self._deadregion[0] * NSEC_PER_SEC + self._deadregion[1] * NSEC_PER_TICK
    cdef long long _dead_interval_stop_nsec = self._deadregion[2] * NSEC_PER_SEC + self._deadregion[3] * NSEC_PER_TICK
    cdef long long _dead_interval_nsec = _dead_interval_stop_nsec - _dead_interval_start_nsec

    if numpy.any(self._trigger_enable_time_nsec[dr_start : dr_end] == -1):
      # start times not determined yet for all channels
      if _dead_interval_start_nsec == 0 and _dead_interval_stop_nsec > 0:
        # if only start is zero, it's daqmode 12 per card and we can estimate the trigger enable timestamp from that
        self._trigger_enable_time_nsec[dr_start : dr_end] = _dead_interval_stop_nsec
      elif _dead_interval_start_nsec == 0 and _dead_interval_stop_nsec == 0:
        # timeoffset[6] is in usec
        _unix_start_time_nsec = (NSEC_PER_SEC * self._timeoffset[5] + 1000 * self._timeoffset[6])
        self._trigger_enable_time_nsec[dr_start : dr_end] = _unix_start_time_nsec

    if _dead_interval_start_nsec > 0:
      # if first event contains start and stop stamps, it's a new dead interval before this event
      self._dead_interval_buffer.add(_dead_interval_start_nsec, _dead_interval_stop_nsec, self._deadregion[5], self._deadregion[6])

    self._dead_interval_nsec[dr_start : dr_end] = 0
    while self._dead_interval_buffer.is_before(_daq_synchronized_timestamp_nsec, self._deadregion[5], self._deadregion[6]):
      self._dead_interval_nsec[dr_start : dr_end] = self._dead_interval_buffer.read(self._deadregion[5], self._deadregion[6])
      self._dead_time_nsec[dr_start : dr_end] += self._dead_interval_nsec[dr_start : dr_end]

    self._run_time_nsec = self._fpga_time_nsec - self._trigger_enable_time_nsec
    self._life_time_nsec = self._run_time_nsec - self._dead_time_nsec

    # provide conversion to seconds
    self._unix_time_utc_sec = self._unix_time_utc_nsec / NSEC_PER_SEC
    self._fpga_time_sec = self._fpga_time_nsec / NSEC_PER_SEC
    self._run_time_sec = self._run_time_nsec / NSEC_PER_SEC
    self._life_time_sec = self._life_time_nsec / NSEC_PER_SEC
    self._dead_time_sec = self._dead_time_nsec / NSEC_PER_SEC
    self._dead_interval_sec = self._dead_interval_nsec / NSEC_PER_SEC

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
  def fpga_time_nsec(self):
    """
    The number of nanoseconds since daq reset.
    """
    return self._fpga_time_nsec

  @property
  def fpga_time_sec(self):
    """
    The number of nanoseconds since daq reset.
    """
    return self._fpga_time_sec

  @property
  def unix_time_utc_nsec(self):
    """
    The number of nanoseconds since 1970 (UTC unix timestamps).
    """
    return self._unix_time_utc_nsec

  @property
  def unix_time_utc_sec(self):
    """
    utc_unix_ns in seconds as float64.
    Be aware that float64 on your machine probably doesn't allow for a precision better than microseconds.
    """
    return self._unix_time_utc_sec

  @property
  def dead_interval_nsec(self):
    """
    The dead time since the last triggered event in nanoseconds.
    """
    return self._dead_interval_nsec[self.trace_list]

  @property
  def dead_interval_sec(self):
    """
    The dead time since the last triggered event in nanoseconds.
    """
    return self._dead_interval_sec[self.trace_list]

  @property
  def run_time_nsec(self):
    """
    """
    return self._run_time_nsec[self.trace_list]

  @property
  def run_time_sec(self):
    """
    """
    return self._run_time_sec[self.trace_list]

  @property
  def dead_time_nsec(self):
    """
    """
    return self._dead_time_nsec[self.trace_list]

  @property
  def dead_time_sec(self):
    """
    """
    return self._dead_time_sec[self.trace_list]

  @property
  def life_time_nsec(self):
    """
    """
    return self._life_time_nsec[self.trace_list]

  @property
  def life_time_sec(self):
    """
    """
    return self._life_time_sec[self.trace_list]

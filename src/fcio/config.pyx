from .def_fcio cimport fcio_config

cimport numpy
import numpy

cdef class Config:
  """
  Class internal to the fcio library. Do not allocate directly, must be created by using `fcio_open` or
  FCIO.open().
  Represents the immutable readout configuration after starting a daq run.
  Guaranteed to be the first record in the stream.
  When concatenating streams or runs, might be sent again (with different values). Therefor it is advisable,
  to access these values as attributes from this class and not copy them somewhere else in the code.
  """
  cdef fcio_config *config

  cdef numpy.ndarray _tracemap
  cdef numpy.int32_t _ntraces
  cdef numpy.int32_t _sampling_frequency_hz
  cdef numpy.int32_t _sampling_period_ns

  def __cinit__(self, fcio : FCIO):
    self.config = &fcio._fcio_data.config

    self._ntraces = self.config.adcs + self.config.triggers

    cdef unsigned int[::1] tracemap_view = self.config.tracemap
    self._tracemap = numpy.ndarray(shape=(self._ntraces,), dtype=numpy.uint32, offset=0, buffer=tracemap_view)

    if self.config.adcbits == 16:
      self._sampling_frequency_hz = 62500000
      self._sampling_period_ns = 16
    elif self.config.adcbits == 12:
      self._sampling_frequency_hz = 250000000
      self._sampling_period_ns = 4

  @property
  def streamid(self):
    """
    The id of this data stream.
    """
    return numpy.int32(self.config.streamid)

  @property
  def adcs(self):
    """
    The number of mapped adc channels.
    """
    return numpy.int32(self.config.adcs)

  @property
  def triggers(self):
    """
    The number of mapped trigger channels. This is one channel per trigger card. Only used in the 12-bit firmware.
    """
    return numpy.int32(self.config.triggers)

  @property
  def eventsamples(self):
    """
    The number of samples configured. This determines the length of the waveforms.
    """
    return numpy.int32(self.config.eventsamples)

  @property
  def adcbits(self):
    """
    The dynamic range of each sample, can be either 12 or 16. Determine by the firmware loaded.
    """
    return numpy.int32(self.config.adcbits)

  @property
  def sampling_period_ns(self):
    """
    The sampling period in nanoseconds of the digitizer used in this datastream.
    """
    return self._sampling_period_ns

  @property
  def sampling_frequency_hz(self):
    """
    The sampling frequency in Hz of the digitizer used in this datastream.
    """
    return self._sampling_frequency_hz

  @property
  def sumlength(self):
    """
    For 12-bit firmware:
      The number of samples used for the integrator value.
      If sumlength >= blprecision use
      integrator = sumlength/blprecision * (theader[1] - theader[0])
      if sumlength < blprecision use
      integrator = theader[1] - theader[0] * sumlength / blprecision
    For 16-bit firmware:
      No meaning.
    """
    return numpy.int32(self.config.sumlength)

  @property
  def blprecision(self):
    """
    For the 12-bit firmware, the baseline is calculated in higher precision (16-bit) and written as unsigned short
    in the trace header fields of the Event struct. To recover the correct units, the theader[0] field has to be divided
    by the blprecision parameter. For the 16-bit firmware this field is 1, allowing indifferent code.
    """
    return numpy.int32(self.config.blprecision)

  @property
  def mastercards(self):
    """
    Number of mastercards mapped during readout.
    """
    return numpy.int32(self.config.mastercards)

  @property
  def triggercards(self):
    """
    Number of triggercards mapped during readout.
    """
    return numpy.int32(self.config.triggercards)

  @property
  def adccards(self):
    """
    Number of adccards mapped during readout.
    """
    return numpy.int32(self.config.adccards)

  @property
  def gps(self):
    """
    GPS mode.
    0: no connected external pps/clock (gps)
    >0: external pps/clock is used, and the value signifies the maximum acceptable delta between pps counters and unix seconds in microseconds.
    """
    return numpy.int32(self.config.gps)

  @property
  def tracemap(self):
    """
    1D Array of unsigned integers containing the fadc/trigger card address and input channel (front connected).
    Format is (address <<16) + channel.
    The index of the array is the same as the trace array indices, allowing to lookup the corresponding information.
    """
    return self._tracemap

from cfcio cimport fcio_config

cimport numpy
import numpy

cdef class CyConfig:
  cdef fcio_config *config

  cdef numpy.ndarray _tracemap
  cdef int ntraces

  def __cinit__(self, fcio : CyFCIO):
    self.config = &fcio._fcio_data.config

    self.ntraces = self.config.adcs + self.config.triggers

    cdef unsigned int[:] tracemap_view = self.config.tracemap
    self._tracemap = numpy.ndarray(shape=(self.ntraces,), dtype=numpy.uint32, offset=0, buffer=tracemap_view)

  @property
  def telid(self):
    return numpy.int32(self.config.telid)

  @property
  def adcs(self):
    return numpy.int32(self.config.adcs)

  @property
  def triggers(self):
    return numpy.int32(self.config.triggers)

  @property
  def eventsamples(self):
    return numpy.int32(self.config.eventsamples)

  @property
  def adcbits(self):
    return numpy.int32(self.config.adcbits)

  @property
  def sumlength(self):
    return numpy.int32(self.config.sumlength)

  @property
  def blprecision(self):
    return numpy.int32(self.config.blprecision)

  @property
  def mastercards(self):
    return numpy.int32(self.config.mastercards)

  @property
  def triggercards(self):
    return numpy.int32(self.config.triggercards)

  @property
  def adccards(self):
    return numpy.int32(self.config.adccards)

  @property
  def gps(self):
    return numpy.int32(self.config.gps)

  @property
  def tracemap(self):
    return self._tracemap
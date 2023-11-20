from cfcio cimport fcio_status, card_status

cimport numpy
import numpy

cdef class CyCardStatus:
  cdef fcio_status *status
  cdef card_status *card_status

  cdef int index # index in original array

  cdef numpy.ndarray _linkstates
  cdef numpy.ndarray _ctilinks
  cdef numpy.ndarray _environment
  cdef numpy.ndarray _othererrors

  def __cinit__(self, cy_status : CyStatus, index):

    self.status = cy_status.status
    self.card_status = &cy_status.status.data[index]
    self.index = index

    cdef unsigned int[:] linkstates_view = self.card_status.linkstates
    cdef unsigned int[:] ctilinks_view = self.card_status.ctilinks
    cdef unsigned int[:] othererrors_view = self.card_status.othererrors
    cdef int[:] environment_view = self.card_status.environment

    self._linkstates = numpy.ndarray(shape=(256), dtype=numpy.uint32, offset=0, buffer=linkstates_view)
    self._ctilinks = numpy.ndarray(shape=(4), dtype=numpy.uint32, offset=0, buffer=ctilinks_view)
    self._environment = numpy.ndarray(shape=(16), dtype=numpy.int32, offset=0, buffer=environment_view)
    self._othererrors = numpy.ndarray(shape=(5), dtype=numpy.uint32, offset=0, buffer=othererrors_view)

  cdef update(self):
    self._linkstates = numpy.lib.stride_tricks.as_strided(self._linkstates, shape=(self.status.data[self.index].numlinks,), writeable=False)
    self._ctilinks = numpy.lib.stride_tricks.as_strided(self._ctilinks, shape=(self.status.data[self.index].numctilinks,), writeable=False)
    self._environment = numpy.lib.stride_tricks.as_strided(self._environment, shape=(self.status.data[self.index].numenv,), writeable=False)

  @property
  def reqid(self):
    return numpy.uint32(self.card_status.reqid)

  @property
  def status(self):
    return numpy.uint32(self.card_status.status)

  @property
  def eventno(self):
    return numpy.uint32(self.card_status.eventno)

  @property
  def pps(self):
    return numpy.uint32(self.card_status.pps)

  @property
  def ticks(self):
    return numpy.uint32(self.card_status.ticks)

  @property
  def maxticks(self):
    return numpy.uint32(self.card_status.maxticks)

  @property
  def numenv(self):
    return numpy.uint32(self.card_status.numenv)

  @property
  def numctilinks(self):
    return numpy.uint32(self.card_status.numctilinks)

  @property
  def numlinks(self):
    return numpy.uint32(self.card_status.numlinks)

  @property
  def dummy(self):
    return numpy.uint32(self.card_status.dummy)

  @property
  def totalerrors(self):
    return numpy.uint32(self.card_status.totalerrors)

  @property
  def enverrors(self):
    return numpy.uint32(self.card_status.enverrors)
  
  @property
  def ctierrors(self):
    return numpy.uint32(self.card_status.ctierrors)

  @property
  def linkerrors(self):
    return numpy.uint32(self.card_status.linkerrors)

  @property
  def othererrors(self):
    return self._othererrors
  
  @property
  def environment(self):
    return self._environment

  @property
  def ctilinks(self):
    return self._ctilinks

  @property
  def linkstates(self):
    return self._linkstates

cdef class CyStatus:
  cdef fcio_config *config
  cdef fcio_status *status

  cdef numpy.ndarray _statustime
  cdef numpy.ndarray _data

  cdef int num_cards

  def __cinit__(self, fcio : CyFCIO):
    self.status = &fcio._fcio_data.status
    self.config = &fcio._fcio_data.config
    self.num_cards = self.config.mastercards + self.config.triggercards + self.config.adccards

    self._data = numpy.array([CyCardStatus(self, index) for index in range(self.num_cards)], dtype=object)

    cdef int[:] statustime_view = self.status.statustime
    self._statustime = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=statustime_view)

  cdef update(self):
    if self.num_cards != self.status.cards:
      self.num_cards = self.status.cards
      self._data = numpy.array([CyCardStatus(self, index) for index in range(self.num_cards)], dtype=object)

    cdef CyCardStatus current_card_status
    for cs in self._data:
      current_card_status = cs
      current_card_status.update()

  @property
  def status(self):
    return numpy.int32(self.status.status)

  @property
  def statustime(self):
    return self._statustime

  @property
  def cards(self):
    return numpy.int32(self.status.cards)

  @property
  def size(self):
    return numpy.int32(self.status.size)

  @property
  def data(self):
    return self._data
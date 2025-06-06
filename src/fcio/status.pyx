from .def_fcio cimport fcio_status, card_status

cimport numpy
import numpy

cdef class CardStatus:
  cdef fcio_status *status
  cdef card_status *card_status

  cdef int index # index in original array

  cdef numpy.ndarray _linkstates
  cdef numpy.ndarray _ctilinks
  cdef numpy.ndarray _environment
  cdef numpy.ndarray _othererrors

  def __cinit__(self, status : Status, index):

    self.status = status.status
    self.card_status = &status.status.data[index]
    self.index = index

    cdef unsigned int[::1] linkstates_view = self.card_status.linkstates
    cdef unsigned int[::1] ctilinks_view = self.card_status.ctilinks
    cdef unsigned int[::1] othererrors_view = self.card_status.othererrors
    cdef int[::1] environment_view = self.card_status.environment

    self._linkstates = numpy.ndarray(shape=(256), dtype=numpy.uint32, offset=0, buffer=linkstates_view)
    self._ctilinks = numpy.ndarray(shape=(4), dtype=numpy.uint32, offset=0, buffer=ctilinks_view)
    self._environment = numpy.ndarray(shape=(16), dtype=numpy.int32, offset=0, buffer=environment_view)
    self._othererrors = numpy.ndarray(shape=(5), dtype=numpy.uint32, offset=0, buffer=othererrors_view)

  @property
  def reqid(self):
    """
    Current request id.
    """
    return numpy.uint32(self.card_status.reqid)

  @property
  def status(self):
    """
    Status of this card:
    1 : ok,
    0 : error
    """
    return numpy.uint32(self.card_status.status)

  @property
  def eventno(self):
    """
    The current event number (counter) when the Status was requested.
    """
    return numpy.uint32(self.card_status.eventno)

  @property
  def pps(self):
    """
    The current pps counter.
    """
    return numpy.uint32(self.card_status.pps)

  @property
  def ticks(self):
    """
    The current ticks counter.
    """
    return numpy.uint32(self.card_status.ticks)

  @property
  def maxticks(self):
    """
    The current maxticks. (Ticks counter when the last pps arrived.)
    """
    return numpy.uint32(self.card_status.maxticks)

  @property
  def fpga_time_sec(self):
    """
    The current time in nanoseconds in units of fpga clock.
    """
    return numpy.float64(self.card_status.pps + 4e-9 * self.card_status.ticks)

  @property
  def fpga_time_nsec(self):
    """
    The current time in nanoseconds in units of fpga clock.
    """
    return numpy.int64(1000000000 * self.card_status.pps + 4 * self.card_status.ticks)

  @property
  def numenv(self):
    """
    Size of the environment array.
    """
    return numpy.uint32(self.card_status.numenv)

  @property
  def numctilinks(self):
    """
    Size of the ctilinks array.
    """
    return numpy.uint32(self.card_status.numctilinks)

  @property
  def numlinks(self):
    """
    Size of linkstates array.
    """
    return numpy.uint32(self.card_status.numlinks)

  @property
  def dummy(self):
    """
    Ignored value..
    """
    return numpy.uint32(self.card_status.dummy)

  @property
  def totalerrors(self):
    """
    Sum of enverrors, ctierrors and linkerrors.
    """
    return numpy.uint32(self.card_status.totalerrors)

  @property
  def enverrors(self):
    """
    Number of errors from environment sensors.
    """
    return numpy.uint32(self.card_status.enverrors)

  @property
  def ctierrors(self):
    """
    Number of errors on the CTI connection.
    """
    return numpy.uint32(self.card_status.ctierrors)

  @property
  def linkerrors(self):
    """
    Number of errors on the trigger links (only relevant if trigger cards are attached).
    """
    return numpy.uint32(self.card_status.linkerrors)

  @property
  def othererrors(self):
    """
    5 possible other erros. Check fc250b source code for more information.
    """
    return self._othererrors

  @property
  def environment(self):
    """
    Contains information from the on-board environment sensors in the following order:
    5 temperatures in mDegree
    6 voltages in mV
    1 main current im mA
    1 humidity in o/oo
    2 temperatures in mDegree, only present if adc piggy cards are used (adc card).
    """
    return self._environment[:self.status.data[self.index].numenv]

  @property
  def mainboard_temperatures_mC(self):
    return self._environment[:5]

  @property
  def mainboard_voltages_mV(self):
    return self._environment[5:11]

  @property
  def mainboard_current_mA(self):
    return self._environment[11]

  @property
  def mainboard_humiditiy_permille(self):
    return self._environment[12]

  @property
  def daughterboard_temperatures_mC(self):
    # might be empty
    return self._environment[13:self.status.data[self.index].numenv]

  @property
  def ctilinks(self):
    """
    Contain expert values, see fc250bcommands.h.
    """
    return self._ctilinks[:self.status.data[self.index].numctilinks]

  @property
  def linkstates(self):
    """
    Contain expert values, see fc250bcommands.h.
    """
    return self._linkstates[:self.status.data[self.index].numlinks]

cdef class Status:
  """
  Class internal to the fcio library. Do not allocate directly, must be created by using `fcio_open` or
  FCIO.open().
  Exposes the fcio_status struct fields from the fcio.c library.
  All fields are exposes as numpy scalars or arrays with their corresponsing datatype and size.
  The card status fields are accessible via the `data` attribute array
  """
  cdef fcio_config *config
  cdef fcio_status *status

  cdef numpy.ndarray _statustime
  cdef numpy.ndarray _data

  cdef int num_cards

  def __cinit__(self, fcio : FCIO):
    self.status = &fcio._fcio_data.status
    self.config = &fcio._fcio_data.config
    self.num_cards = self.config.mastercards + self.config.triggercards + self.config.adccards

    self._data = numpy.array([CardStatus(self, index) for index in range(self.num_cards)], dtype=object)

    cdef int[::1] statustime_view = self.status.statustime
    self._statustime = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=statustime_view)

  @property
  def status(self):
    """
    Overall status flag of the system.
    1 : no errors
    0 : errors did occur on some card
    """
    return numpy.int32(self.status.status)

  @property
  def statustime(self):
    """
    1D array containing time information of this status record.
    Offsets:
    0 : fc250 (mastercard) seconds since run start
    1 : fc250 (mastercard) microseconds since last second
    2 : unix utc (server) seconds
    3 : unix utc (server) microseconds since last unix second
    5 : pps counter when the trigger was enabled after start of the daq
    6 : microseconds since [5]

    5/6 signifies a start of the run offset one needs to for deadtime calculation
    """
    return self._statustime

  @property
  def fpga_time_sec(self):
      """
        Floating point calculation of statustime[0] * 1e-6 * statustime[1]
      """
      return numpy.float64(self._statustime[0] + 1e-6 * self._statustime[1])

  @property
  def unix_time_utc_sec(self):
      """
        Floating point calculation of statustime[1] * 1e-6 * statustime[3]
      """
      return numpy.float64(self._statustime[2] + 1e-6 * self._statustime[3])

  @property
  def fpga_start_time_sec(self):
      """
        Floating point calculation of statustime[5] * 1e-6 * statustime[6]
      """
      return numpy.float64(self._statustime[5] + 1e-6 * self._statustime[6])

  @property
  def cards(self):
    """
    The total number of cards present in the `data` attribute
    """
    return numpy.int32(self.status.cards)

  @property
  def size(self):
    """
    The size in bytes of each original card_status struct in fcio.c
    """
    return numpy.int32(self.status.size)

  @property
  def data(self):
    """
    An array of CardStatus objects. The type of card is ordered as master -> trigger -> adc card and their counts should be taken from the Config attributes.

    """
    return self._data[:self.status.cards]

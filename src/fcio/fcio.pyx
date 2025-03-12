from .def_fcio cimport FCIOOpen, FCIOClose, FCIODebug, FCIOGetRecord, FCIOTimeout, FCIOStreamHandle, FCIOData, FCIOTag
from .def_fcio cimport FCIOMaxChannels, FCIOMaxSamples, FCIOMaxPulses, FCIOTraceBufferLength
from .def_fcio cimport FCIOSetMemField, FCIOStreamBytes

cimport cython
cimport numpy

import tempfile, os, subprocess
from warnings import warn

include "dead_interval_tracker.pyx"
include "extension.pyx"
include "config.pyx"
include "event.pyx"
include "recevent.pyx"
include "status.pyx"

include "fsp.pyx"

cdef class Tags:
  """
  A wrapper class for the fcio tag enum.
  Provides supported tags as attributes.
  """

  Config = FCIOTag.FCIOConfig
  Event = FCIOTag.FCIOEvent
  Status = FCIOTag.FCIOStatus
  RecEvent = FCIOTag.FCIORecEvent
  SparseEvent = FCIOTag.FCIOSparseEvent
  EventHeader = FCIOTag.FCIOEventHeader
  FSPConfig = FCIOTag.FCIOFSPConfig
  FSPEvent = FCIOTag.FCIOFSPEvent
  FSPStatus = FCIOTag.FCIOFSPStatus

  # could be replaced with FCIOTagStr(int tag) in fcio_utils.c
  def str(tag):
    if tag == FCIOTag.FCIOConfig:
      return "Config"
    elif tag == FCIOTag.FCIOEvent:
      return "Event"
    elif tag == FCIOTag.FCIOStatus:
      return "Status"
    elif tag == FCIOTag.FCIORecEvent:
      return "RecEvent"
    elif tag == FCIOTag.FCIOSparseEvent:
      return "SparseEvent"
    elif tag == FCIOTag.FCIOEventHeader:
      return "EventHeader"
    elif tag == FCIOTag.FCIOFSPConfig:
      return "FSPConfig"
    elif tag == FCIOTag.FCIOFSPEvent:
      return "FSPEvent"
    elif tag == FCIOTag.FCIOFSPStatus:
      return "FSPStatus"
    else:
      return "Unknown"

class Limits:
  """
  A wrapper class to expose the compile time defines used in fcio.c
  """
  MaxChannels = FCIOMaxChannels
  MaxSamples = FCIOMaxSamples
  MaxPulses = FCIOMaxPulses
  TraceBufferLength = FCIOTraceBufferLength

cdef class FCIO:
  """
  The main class providing access to the data fields.
  Interaction mainly by using the get_record() function or FCIO's properties.

  Parameters
  ----------
  peer : str
    the path to the peer to open, can be zst or gzip compressed files.

  timeout : int
    the timeout with which the connection should happend in milliseconds.
    default: 0
    -1 : wait indefinitely
    >=0 : wait these milliseconds and return

  buffersize : int
    the size of the internal buffer used by bufio in bytes.
    default: 0 uses bufios sane default size

  debug : int
    sets the debug level of the fcio.c library using FCIODebug(debug)
    does not affect the verbosity of fcio-py parts
    default: 0

  compression : str
    allows decompressing the file pointed to by peer while reading.
    'zst'  : use zstd executable to open file. autodetected if file ends with '.zst'
    'gzip' : use gzip executable to open file. autodetected if file ends with '.gz'
    default 'auto' : determines possible compression by inspecting the peer ending

  extended : bool
    enables additional properties of the FCIO record classes by replacing the FCIO properties with their extended classes.
    e.g. type(FCIO.event) == Event or EventExt
    some of these additions require additional calculations during reading, which might not be required and can be turned off by
    setting 'extended' to False.
    default: True

    these properties provide access to:
    - values derived from more basic values in the record
    - explicit naming of certain field entries
    - explicit limits to some array accessing, which fall on the responsibility of the programmer in the fcio.c library

    examples:
    - FCIO.event.card_address exposes an unsigned short array for the channels recorded in this event
    - FCIO.event.utc_unix applies the reference way to calculate the absolute time from the Config and Event records (timestamp and timeoffset depending on gps clock presence)
    - FCIO.event.trace array only returns the updated waveforms if the record was a SparseEvent
    - FCIO.event.fpga_baseline/.fpga_energy in correct units for both firmware versions
    - ...
  """

  cdef FCIOData* _fcio_data
  cdef int _timeout
  cdef int _buffersize
  cdef int _debug
  cdef int _tag

  cdef object _compression # compression type, <str>
  cdef object _peer        # path to data file, <str>
  cdef object _compression_process # handle for the subprocess
  cdef object _peer_is_memory # mem:// peer is special, we save a boolean to remember

  cdef Config config
  cdef Event event
  cdef RecEvent recevent
  cdef Status status
  cdef bint _extended

  cdef FSP _fsp

  def __cinit__(self, peer : str | char[::1] = None, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto', extended : bool = False):
    self._fcio_data = NULL
    self._peer = peer
    self._buffersize = buffersize
    self._timeout = timeout
    self._debug = debug
    self._compression = compression
    self._extended = extended

    self._fsp = None

    if peer:
      self.open(peer, timeout, buffersize, debug, compression, extended)

  def __dealloc__(self):
    if self._fcio_data != NULL:
      FCIOClose(self._fcio_data)

  def __enter__(self):
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    self.close()

  def __del__(self):
    self.close()

  @property
  def debug(self):
    """
      returns the set debug level
    """
    return self._debug

  @debug.setter
  def debug(self, value):
    """
      set the fcio.c debug level
    """
    self._debug = value
    FCIODebug(self._debug)

  @property
  def timeout(self):
    """
      returns the set timeout in milliseconds
    """
    return self._timeout

  @timeout.setter
  def timeout(self, value):
    """
      adjust the timeout of the fcio.c library FCIOGetRecord functionality
    """
    self._timeout = FCIOTimeout(self._fcio_data, value)

  @property
  def buffersize(self):
    """
      returns the set bufio buffersize in bytes
    """
    return self._buffersize

  def open(self, peer : str | memoryview, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto', extended : bool = False):
    self.close()

    if buffersize:
      self._buffersize = buffersize
    if timeout:
      self._timeout = timeout
    if debug:
      self._debug = debug
    if compression:
      self._compression = compression
    if extended:
      self._extended = extended

    FCIODebug(debug)

    cdef char[::1] memory
    cdef long long print_mem_addr

    if isinstance(peer, str):
      self._peer = peer
      self._peer_is_memory = True if self._peer.startswith("mem://") else False
    else:
      try:
        memory = memoryview(peer).cast('B')
        memory_addr = &memory[0]

        # TODO: investigate what could be used instead of unsigned long to store the memory address savely
        self._peer = f"mem://0x{<unsigned long>memory_addr:x}/{memory.nbytes}"

        self._peer_is_memory = True
      except TypeError:
        return

    if debug > 4:
      print(f"fcio-py/open: peer {self._peer} timeout {self._timeout} buffersize {self._buffersize} debug {self._debug} compression {self._compression} extended {self._extended}")

    if self._compression == 'auto':
      if self._peer.endswith('.zst') or self._peer.endswith('.zstd'):
        self._compression = 'zstd'
      elif self._peer.endswith('.gz'):
        self._compression = 'gzip'
      else:
        self._compression = 'none'

    # 1 second minimum timeout for launching the subprocess to decompress the file
    cdef int compression_minimum_timeout = 1000

    if self._compression == 'zstd':
      tmpdir = tempfile.TemporaryDirectory(prefix="fcio_")
      if self._timeout >= 0 and self._timeout < compression_minimum_timeout:
        self._timeout = compression_minimum_timeout
      fifo = os.path.join(tmpdir.name, os.path.basename(self._peer))
      os.mkfifo(fifo)
      self._compression_process = subprocess.Popen(["zstd","-df","--no-progress","-q","--no-sparse","-o",fifo,self._peer])
      self._fcio_data = FCIOOpen(fifo.encode(u"ascii"), self._timeout, self._buffersize)
      os.unlink(fifo)
      tmpdir.cleanup()
      if self._fcio_data == NULL:
        raise IOError(f"{self._peer} couldn't be opened. The decompression is handled by a subprocess. Try increasing the timeout.")

    elif self._compression == 'gzip':
      tmpdir = tempfile.TemporaryDirectory(prefix="fcio_")
      if self._timeout >= 0 and self._timeout < compression_minimum_timeout:
        self._timeout = compression_minimum_timeout
      fifo = os.path.join(tmpdir.name, os.path.basename(self._peer))
      os.mkfifo(fifo)
      self._compression_process = subprocess.Popen(["gzip","q","-d","-c",self._peer,">",fifo])
      self._fcio_data = FCIOOpen(fifo.encode(u"ascii"), self._timeout, self._buffersize)
      os.unlink(fifo)
      tmpdir.cleanup()
      if self._fcio_data == NULL:
        raise IOError(f"{self._peer} couldn't be opened. The decompression is handled by a subprocess. Try increasing the timeout.")

    elif self._compression == 'none':
      self._fcio_data = FCIOOpen(self._peer.encode(u"ascii"), self._timeout, self._buffersize)
    else:
      raise ValueError(f"Compression parameter {self._compression} is not supported. Files ending in '.zst' or '.gz' will be automatically decompressed during reading.")

    if self._fcio_data == NULL:
      raise IOError(f"Couldn't open: {self._peer}")

    while self.get_record():
      if self._tag == FCIOTag.FCIOConfig:
        break

  def close(self) -> None:
    """
      If a datafile is opened, close it and deallocate the FCIOData structure.
    """
    if self._fcio_data:
      FCIOClose(self._fcio_data)
      self._fcio_data = NULL

  def is_open(self) -> bool:
    """
      Returns True/False if the internal data structur is allocated (i.e. if
      open() has been called without closing.
      No connection checks to remote peers are performed.
    """
    return self._fcio_data != NULL

  def set_mem_field(self, mview not None):
    cdef char[::1] memory
    try:
      memory = memoryview(mview).cast('B')
    except TypeError as e:
      raise TypeError('fcio-py/set_mem_field requires an object which supports the PEP 3118 buffer interface').with_traceback(e.__traceback__)
    if self._peer_is_memory:
      if 0 != FCIOSetMemField(FCIOStreamHandle(self._fcio_data), &memory[0], memory.nbytes):
        raise IOError(f"Couldn't set memory field: {memory}")
    else:
      warn(f"fcio-py/set_mem_field was called but peer is not mem:// : {self._peer}, ignoring.")

  cpdef get_record(self):
    """
      Calls FCIOGetRecord.
      Saves the returned tag (accessible via FCIO.tag).

      Returns False if the tag <= 0 indicating either a stream error or timeout.
      Returns True otherwise.
    """
    if self._fcio_data:
      self._tag = FCIOGetRecord(self._fcio_data)

      if self._tag == FCIOTag.FCIOConfig:
        # config must always be allocated first.
        self.config = Config(self)
        self.status = Status(self)
        self.event = Event(self)
        self.recevent = RecEvent(self)
      elif (self._tag in [FCIOTag.FCIOEvent, FCIOTag.FCIOSparseEvent, FCIOTag.FCIOEventHeader]):
        self.event.update()
      elif self._tag == FCIOTag.FCIORecEvent:
        self.recevent.update()
      elif self._tag == FCIOTag.FCIOFSPConfig:
        self._fsp = FSP()
        self._fsp.read_config(self)
      elif self._tag == FCIOTag.FCIOFSPEvent:
        self._fsp.read_event(self)
      elif self._tag == FCIOTag.FCIOFSPStatus:
        self._fsp.read_status(self)
      elif self._tag <= 0:
        return False

      return True
    else:
      raise IOError(f"File {self._peer} not opened.")

  @property
  def tag(self):
    """
      returns the current tag
    """
    return self._tag

  @property
  def config(self):
    """
      returns the current FCIOConfig record
    """
    return self.config

  @property
  def event(self):
    """
      returns the current FCIOEvent record
    """
    return self.event

  @property
  def recevent(self):
    """
      returns the current FCIORecEvent record
    """
    return self.recevent

  @property
  def status(self):
    """
      returns the current FCIOStatus record
    """
    return self.status

  @property
  def tags(self):
    """
      Iterate through all FCIO records in the datastream.

      Returns the current tag. Comparable behaviour to FCIOGetRecord of fcio.c
    """
    while self.get_record():
      yield self._tag

  @property
  def configs(self):
    """
      Iterate through all FCIOConfig records in the datastream.

      Returns the current config.
    """
    while self.get_record():
      if self._tag == FCIOTag.FCIOConfig:
        yield self.config

  @property
  def events(self):
    """
      Iterate through all FCIOEvent or FCIOSparseEvent records in the datastream.

      Returns the current event.
    """
    while self.get_record():
      if self._tag in [FCIOTag.FCIOEvent, FCIOTag.FCIOSparseEvent, FCIOTag.FCIOEventHeader]:
        yield self.event

  @property
  def recevents(self):
    """
      Iterate through all FCIORecEvent records in the datastream.

      Returns the current event.
    """
    while self.get_record():
      if self._tag == FCIOTag.FCIORecEvent:
        yield self.recevent

  @property
  def statuses(self):
    """
      Iterate through all FCIOStatus records in the datastream.

      Returns the current event.
    """
    while self.get_record():
      if self._tag == FCIOTag.FCIOStatus:
        yield self.status

  @property
  def fsp(self):
    return self._fsp

  def read_bytes(self, offset=0):
    """
        Returns the number of bytes read from stream since opening.
        If offset is != 0, offset will be subtracted from the total,
        allowing quick calculation of deltas as in:

        n_delta_bytes = fcio.read_bytes(0)

        while fcio.get_record()
            n_delta_bytes = fcio.read_bytes(n_delta_bytes)
    """
    return FCIOStreamBytes(FCIOStreamHandle(self._fcio_data), b'r', offset)

  def skipped_bytes(self, offset=0):
    """
        Returns the number of bytes skipped from stream since opening.
        If offset is != 0, offset will be subtracted from the total,
        allowing quick calculation of deltas as in:

        n_delta_bytes = fcio.skipped_bytes(0)

        while fcio.get_record()
            n_delta_bytes = fcio.skipped_bytes(n_delta_bytes)
    """
    return FCIOStreamBytes(FCIOStreamHandle(self._fcio_data), b's', offset)

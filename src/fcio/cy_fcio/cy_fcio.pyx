from cfcio cimport FCIOOpen, FCIOClose, FCIODebug, FCIOGetRecord, FCIOTimeout, FCIOData, FCIOTag
cimport numpy
import tempfile, os, subprocess

include "cy_fcio_config.pyx"
include "cy_fcio_event.pyx"
include "cy_fcio_status.pyx"
include "cy_fcio_event_ext.pyx"

class CyFCIOTag:
  Config = FCIOTag.FCIOConfig
  Event = FCIOTag.FCIOEvent
  Status = FCIOTag.FCIOStatus
  RecEvent = FCIOTag.FCIORecEvent
  SparseEvent = FCIOTag.FCIOSparseEvent

cdef class CyFCIO:
  cdef FCIOData* _fcio_data
  cdef int _timeout
  cdef int _buffersize
  cdef int _debug
  cdef int _tag

  cdef object _compression # compression type, <str>
  cdef object _filename    # path to data file, <str>
  cdef object _compression_process # handle for the subprocess
  
  cdef CyConfig config
  cdef CyEvent event
  cdef CyStatus status
  cdef bint _extended

  def __cinit__(self, filename : str = None, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto', extended : bool = True):
    self._fcio_data = NULL
    self._buffersize = buffersize
    self._timeout = timeout
    self._debug = debug
    self._compression = compression

    self._extended = extended

    FCIODebug(self.debug)

    if filename:
      self._filename = filename
      self.open(filename)

  def __dealloc__(self):
    if self._fcio_data != NULL:
      FCIOClose(self._fcio_data)

  def __enter__(self):
    self.open(self._filename)
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    self.close()

  def __del__(self):
    self.close()

  @property
  def debug(self):
    return self._debug

  @debug.setter
  def debug(self, value):
    self._debug = value
    FCIODebug(self._debug)

  @property
  def timeout(self):
    return self._timeout

  @timeout.setter
  def timeout(self, value):
    self._timeout = FCIOTimeout(self._fcio_data, value)

  @property
  def buffersize(self):
    return self._buffersize

  def open(self, filename : str, timeout : int = None, buffersize : int = None, debug : int = None, compression : str = None):
    self.close()

    self._filename = filename

    if buffersize:
      self._buffersize = buffersize
    if timeout:
      self.timeout = timeout
    if debug:
      self.debug = debug
    if compression:
      self._compression = compression

    if self._compression is 'auto':
      if self._filename.endswith('.zst'):
        self._compression = 'zstd'
      elif self._filename.endswith('.gz'):
        self._compression = 'gzip'
      else:
        self._compression = 'none'

    # 1 second minimum timeout for launching the subprocess to decompress the file
    cdef int compression_minimum_timeout = 1000

    if self._compression is 'zstd':
      tmpdir = tempfile.TemporaryDirectory(prefix="fcio_")
      if self._timeout >= 0 and self._timeout < compression_minimum_timeout:
        self._timeout = compression_minimum_timeout
      fifo = os.path.join(tmpdir.name, os.path.basename(self._filename))
      os.mkfifo(fifo)
      self._compression_process = subprocess.Popen(["zstd","-df","--no-progress","-q","--no-sparse","-o",fifo,self._filename])
      self._fcio_data = FCIOOpen(fifo.encode(u"ascii"), self._timeout, self._buffersize)
      os.unlink(fifo)
      tmpdir.cleanup()
      if self._fcio_data == NULL:
        raise IOError(f"{self._filename} couldn't be opened. The decompression is handled by a subprocess. Try increasing the timeout.")
      
    elif self._compression is 'gzip':
      tmpdir = tempfile.TemporaryDirectory(prefix="fcio_")
      if self._timeout >= 0 and self._timeout < compression_minimum_timeout:
        self._timeout = compression_minimum_timeout
      fifo = os.path.join(tmpdir.name, os.path.basename(self._filename))
      os.mkfifo(fifo)
      self._compression_process = subprocess.Popen(["gzip","q","-d","-c",self._filename,">",fifo])
      self._fcio_data = FCIOOpen(fifo.encode(u"ascii"), self._timeout, self._buffersize)
      os.unlink(fifo)
      tmpdir.cleanup()
      if self._fcio_data == NULL:
        raise IOError(f"{self._filename} couldn't be opened. The decompression is handled by a subprocess. Try increasing the timeout.")

    elif self._compression is 'none':
      self._fcio_data = FCIOOpen(self._filename.encode(u"ascii"), self._timeout, self._buffersize)
    else:
      raise ValueError(f"Compression parameter {self._compression} is not supported. Files ending in '.zst' or '.gz' will be automatically decompressed during reading.")

    if self._fcio_data == NULL:
      raise IOError(f"Coudn't open: {self._filename}")

    while self.get_record():
      if self._tag == FCIOTag.FCIOConfig:
        break

  def close(self):
    if self._fcio_data:
      FCIOClose(self._fcio_data)
      self._fcio_data = NULL

  cpdef get_record(self):
    if self._fcio_data:
      self._tag = FCIOGetRecord(self._fcio_data)

      if self._tag == FCIOTag.FCIOConfig:
        # config must always be allocated first.
        self.config = CyConfig(self)
        self.status = CyStatus(self)
        if self._extended:
          self.event = CyEventExt(self)
        else:
          self.event = CyEvent(self)
      elif self._tag == FCIOTag.FCIOEvent or self._tag == FCIOTag.FCIOSparseEvent:
        self.event.update()
      elif self._tag == FCIOTag.FCIOStatus:
        self.status.update()
      elif self._tag == FCIOTag.FCIORecEvent:
        pass
      elif self._tag <= 0:
        return False

      return True
    else:
      raise IOError(f"File {self._filename} not opened.")

  @property
  def tag(self):
    return self._tag
  
  @property
  def config(self):
    return self.config

  @property
  def event(self):
    return self.event

  @property
  def status(self):
    return self.status

  @property
  def tags(self):
    while self.get_record():
      yield self._tag

  @property
  def configs(self):
    while self.get_record():
      if self._tag == FCIOTag.FCIOConfig:
        yield self.config

  @property
  def events(self):
    while self.get_record():
      if self._tag == FCIOTag.FCIOEvent or self._tag == FCIOTag.FCIOSparseEvent:
        # if self._extended:
        #   yield self.event_ext
        # else:
          yield self.event

  @property
  def statuses(self):
    while self.get_record():
      if self._tag == FCIOTag.FCIOStatus:
        yield self.status
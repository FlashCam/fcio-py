from cfcio cimport FCIOOpen, FCIOClose, FCIODebug, FCIOGetRecord, FCIOTimeout, FCIOData, FCIOTag
from cfcio cimport FCIOMaxChannels,FCIOMaxSamples,FCIOMaxPulses,FCIOTraceBufferLength
cimport numpy
import tempfile, os, subprocess

include "cy_fcio_config.pyx"
include "cy_fcio_event.pyx"
include "cy_fcio_status.pyx"
include "cy_fcio_event_ext.pyx"

class CyFCIOTag:
  """
  A wrapper class for the fcio tag enum.
  Provides supported tags as attributes.
  """
  Config = FCIOTag.FCIOConfig
  Event = FCIOTag.FCIOEvent
  Status = FCIOTag.FCIOStatus
  RecEvent = FCIOTag.FCIORecEvent
  SparseEvent = FCIOTag.FCIOSparseEvent

class CyFCIOLimit:
  """
  A wrapper class to expose the compile time defines used in fcio.c
  """
  MaxChannels = FCIOMaxChannels
  MaxSamples = FCIOMaxSamples
  MaxPulses = FCIOMaxPulses
  TraceBufferLength = FCIOTraceBufferLength

cdef class CyFCIO:
  """
  The main class providing access to the data fields.
  Interaction mainly by using the get_record() function or CyFCIO's properties.
  
  Parameters
  ----------
  filename : str
    the path to the filename to open, can be zst or gzip compressed files.

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
    allows decompressing the file pointed to by filename while reading.
    'zst'  : use zstd executable to open file. autodetected if file ends with '.zst'
    'gzip' : use gzip executable to open file. autodetected if file ends with '.gz'
    default 'auto' : determines possible compression by inspecting the filename ending

  extended : bool
    enables additional properties of the FCIO record classes by replacing the FCIO properties with their extended classes.
    e.g. type(FCIO.event) == CyEvent or CyEventExt
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

  def close(self) -> None:
    """
      If a datafile is opened, close it and deallocate the FCIOData structure.
    """
    if self._fcio_data:
      FCIOClose(self._fcio_data)
      self._fcio_data = NULL

  cpdef get_record(self):
    """
      Calls FCIOGetRecord.
      Saves the returned tag (accessible via CyFCIO.tag).

      Returns False if the tag <= 0 indicating either a stream error or timeout.
      Returns True otherwise.
    """
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
      elif self._extended and (self._tag == FCIOTag.FCIOEvent or self._tag == FCIOTag.FCIOSparseEvent):
        self.event.update()
      elif self._tag <= 0:
        return False

      return True
    else:
      raise IOError(f"File {self._filename} not opened.")

  @property
  def tag(self):
    """
      returns the current tag
    """
    return self._tag
  
  @property
  def config(self):
    """
      returns the current FCIOStates record
    """
    return self.config

  @property
  def event(self):
    """
      returns the current FCIOStates record
    """
    return self.event

  @property
  def status(self):
    """
      returns the current FCIOStates record
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
      if self._tag == FCIOTag.FCIOEvent or self._tag == FCIOTag.FCIOSparseEvent:
        yield self.event

  @property
  def statuses(self):
    """
      Iterate through all FCIOStatus records in the datastream.

      Returns the current event.
    """
    while self.get_record():
      if self._tag == FCIOTag.FCIOStatus:
        yield self.status
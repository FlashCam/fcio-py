import cppyy
import numpy as np
import sysconfig

try:
    from importlib.resources import files as import_files
except ImportError:
    from importlib_resources import files as import_files

package_base = import_files("fcio")
fcio_header_path = (package_base / "include" / "fcio.h")
fcio_lib_path = (package_base / f"fcio{sysconfig.get_config_vars('SO')[0]}")

cppyy.include(str(fcio_header_path))
cppyy.load_library(str(fcio_lib_path))

from fcio.cppyy_fcio.config import Config
from fcio.cppyy_fcio.event import Event
from fcio.cppyy_fcio.status import Status, CardStatus

def fcio_open(filename : str, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto'):
  return FCIO(filename, timeout, buffersize, debug, compression)

class FCIO:
  def __init__(self, filename : str = None, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto'):

    # map the known FCIOTags
    self.FCIOEvent = cppyy.gbl.FCIOEvent
    self.FCIOSparseEvent = cppyy.gbl.FCIOSparseEvent
    self.FCIORecEvent = cppyy.gbl.FCIORecEvent
    self.FCIOConfig = cppyy.gbl.FCIOConfig
    self.FCIOStatus = cppyy.gbl.FCIOStatus

    # parse input
    self.timeout = int(timeout)
    self.buffersize = int(buffersize)
    self.debug = int(debug)
    self.compression = compression
    self.buffer = None
    self.last_tag = None
    cppyy.gbl.FCIODebug(self.debug)


    if filename:
      self.filename = filename
      self.open(filename)

  def __enter__(self):
    self.open(self.filename)
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    self.close()

  def __del__(self):
    self.close()

  def open(self, filename : str):
    import tempfile, os, subprocess
    
    if self.buffer:
      self.close()
    self.filename = filename
    
    if self.compression is 'auto':
      if self.filename.endswith('.zst'):
        self.compression = 'zstd'
      elif self.filename.endswith('.gz'):
        self.compression = 'gzip'
      else:
        self.compression = 'none'

    if self.compression is 'zstd':
      tmpdir = tempfile.TemporaryDirectory(prefix="fcio_")
      fifo = os.path.join(tmpdir.name, os.path.basename(self.filename))
      os.mkfifo(fifo)
      self.compression_process = subprocess.Popen(["zstd","-d","--no-progress","-q","--no-sparse","-o",fifo,self.filename])
      self.buffer = cppyy.gbl.FCIOOpen(self.filename.encode(u"ascii"), self.timeout, self.buffersize)
      os.unlink(fifo)
      tmpdir.cleanup()
      
    elif self.compression is 'gzip':
      tmpdir = tempfile.TemporaryDirectory(prefix="fcio_")
      fifo = os.path.join(tmpdir.name, os.path.basename(self.filename))
      os.mkfifo(fifo)
      self.compression_process = subprocess.Popen(["gzip","q","-d","-c",self.filename,">",fifo])
      self.buffer = cppyy.gbl.FCIOOpen(self.filename.encode(u"ascii"), self.timeout, self.buffersize)
      os.unlink(fifo)
      tmpdir.cleanup()

    elif self.compression is 'none':
      self.buffer = cppyy.gbl.FCIOOpen(self.filename.encode(u"ascii"), self.timeout, self.buffersize)
    
    tag = 1
    while tag > 0:
      tag = self.get_record()
      if tag == self.FCIOConfig:
        break

  def close(self):
    if self.buffer:
      cppyy.gbl.FCIOClose(self.buffer)
      self.buffer = None

  def get_record(self):
    if self.buffer:
      self.last_tag = cppyy.gbl.FCIOGetRecord(self.buffer)
      if self.last_tag == self.FCIOConfig:
        self.config = Config(self.buffer.config)
        self.event = Event(self.buffer.event, self.config)
        self.status = Status(self.buffer.status, self.config)
        self.recevent = None
      return self.last_tag
    else:
      raise Exception(f"File {self.filename} not opened.")

  @property
  def records(self):
    tag = 1
    while tag > 0:
      tag = self.get_record()
      yield tag

  @property
  def events(self):
    tag = 1
    while tag > 0:
      tag = self.get_record()
      if tag == self.FCIOEvent or tag == self.FCIOSparseEvent:
        yield self.event
        
  @property
  def recevents(self):
    tag = 1
    while tag > 0:
      tag = self.get_record()
      if tag == self.FCIORecEvent:
        yield self.recevent

  @property
  def statuses(self):
    tag = 1
    while tag > 0:
      tag = self.get_record()
      if tag == self.FCIOStatus:
        yield self.status

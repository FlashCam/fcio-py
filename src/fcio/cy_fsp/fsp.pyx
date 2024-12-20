from fsp_def cimport StreamProcessor, FSPCreate, FSPDestroy
from fsp_def cimport FCIOGetFSPConfig, FCIOGetFSPEvent, FCIOGetFSPStatus

from cython.operator import dereference

cdef class FSPConfig:
  cdef:
    StreamProcessor* _processor

  def __cinit__(self, FSP fsp):
    self._processor = fsp._processor

  @property
  def triggerconfig(self):
    return self._processor.triggerconfig

  @property
  def buffer(self):
    if self._processor.buffer:
      return dereference(self._processor.buffer)
    else:
      return None

  @property
  def wps(self):
    return self._processor.dsp_wps

  @property
  def hwm(self):
    return self._processor.dsp_hwm

  @property
  def ct(self):
    return self._processor.dsp_ct

cdef class FSPEvent:
  cdef:
    StreamProcessor* _processor

  def __cinit__(self, FSP fsp):
    self._processor = fsp._processor

  @property
  def write_flags(self):
    return self._processor.fsp_state.write_flags

  @property
  def proc_flags(self):
    return self._processor.fsp_state.proc_flags

  @property
  def obs(self):
    return self._processor.fsp_state.obs

cdef class FSPStatus:
  cdef:
    StreamProcessor* _processor

  def __cinit__(self, FSP fsp):
    self._processor = fsp._processor

  @property
  def stats(self):
    return self._processor.stats

cdef class FSP:
  cdef:
    StreamProcessor* _processor
    FSPConfig _config
    FSPEvent _event
    FSPStatus _status

  def __cinit__(self):
    self._processor = FSPCreate(0)

    self._config = FSPConfig(self)
    self._status = FSPStatus(self)
    self._event = FSPEvent(self)

  def __del__(self):
    if self._processor != NULL:
      FSPDestroy(self._processor)

  def read_config(self, FCIO fcio):
    FCIOGetFSPConfig(fcio._fcio_data, self._processor)

  def read_event(self, FCIO fcio):
    FCIOGetFSPEvent(fcio._fcio_data, self._processor)

  def read_status(self, FCIO fcio):
    FCIOGetFSPStatus(fcio._fcio_data, self._processor)

  @property
  def event(self):
    return self._event

  @property
  def status(self):
    return self._status

  @property
  def config(self):
    return self._config

from fsp_def cimport StreamProcessor, FSPState, FSPCreate, FSPDestroy
from fsp_def cimport FCIOGetFSPConfig, FCIOGetFSPEvent, FCIOGetFSPStatus
from fsp_def cimport FSPStats

from cython.operator import dereference

cdef class FSPConfig:
  cdef:
    StreamProcessor* _processor

  def __cinit__(self, FSP fsp):
    self._processor = fsp._processor

  @property
  def fsp(self):
    return self._processor.config

  @property
  def buffer(self):
    return dereference(self._processor.buffer)

  @property
  def wps(self):
    return dereference(self._processor.dsp_wps)

  @property
  def hwm(self):
    return dereference(self._processor.dsp_hwm)

  @property
  def ct(self):
    return dereference(self._processor.dsp_ct)

cdef class FSPEvent:
  cdef:
    FSPState* _state

  def __cinit__(self, FSP fsp):
    self._state = &fsp._state

  @property
  def write_flags(self):
    return self._state.write_flags

  @property
  def proc_flags(self):
    return self._state.proc_flags

  @property
  def obs(self):
    return self._state.obs

cdef class FSPStatus:
  cdef:
    FSPStats* _stats

  def __cinit__(self, FSP fsp):
    self._stats = fsp._processor.stats

  @property
  def stats(self):
    return dereference(self._stats)

cdef class FSP:
  cdef:
    FSPState _state
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
    FCIOGetFSPEvent(fcio._fcio_data, &self._state)

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

from cfsp cimport StreamProcessor, FSPState, FSPCallocStreamProcessor, FSPFreeStreamProcessor
from cfsp cimport FCIOGetFSPConfig, FCIOGetFSPEvent, FCIOGetFSPStatus
from cfsp cimport FSPStats, FSPConfig, FSPObservables, WindowedPeakSumConfig, HardwareMajorityConfig, ChannelThresholdConfig
from cython.operator import dereference

from cy_fcio import CyFCIO

cdef class CyFSPConfig:
  cdef:
    StreamProcessor* _processor

  def __cinit__(self, CyFSP fsp):
    self._processor = fsp._processor

  @property
  def fsp(self):
    return self._processor.config

  @property
  def buffer(self):
    return dereference(self._processor.buffer)

  @property
  def wps(self):
    return dereference(self._processor.wps_cfg)

  @property
  def hwm(self):
    return dereference(self._processor.hwm_cfg)

  @property
  def ct(self):
    return dereference(self._processor.ct_cfg)

cdef class CyFSPEvent:
  cdef:
    FSPState* _state

  def __cinit__(self, CyFSP fsp):
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

cdef class CyFSPStatus:
  cdef:
    FSPStats* _stats

  def __cinit__(self, CyFSP fsp):
    self._stats = fsp._processor.stats

  @property
  def stats(self):
    return dereference(self._stats)

cdef class CyFSP:
  cdef:
    FSPState _state
    StreamProcessor* _processor
    CyFSPConfig _config
    CyFSPEvent _event
    CyFSPStatus _status

  def __cinit__(self):
    self._processor = FSPCallocStreamProcessor()

    self._config = CyFSPConfig(self)
    self._status = CyFSPStatus(self)
    self._event = CyFSPEvent(self)

  def __del__(self):
    if self._processor != NULL:
      FSPFreeStreamProcessor(self._processor)

  def read_config(self, CyFCIO fcio):
    FCIOGetFSPConfig(fcio._fcio_data, self._processor)

  def read_event(self, CyFCIO fcio):
    FCIOGetFSPEvent(fcio._fcio_data, &self._state)

  def read_status(self, CyFCIO fcio):
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
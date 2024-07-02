from cfsp cimport FSPState, FCIOGetFSPConfig, FCIOGetFSPEvent, FCIOGetFSPStatus
from libc.stdlib cimport malloc, free

cdef class CyFSP:
  cdef FSPState _state

  def read_fsp_config(self, CyFCIO fcio):
    # FCIOGetFSPConfig(fcio._fcio_data, &self._processor)
    pass

  def read_fsp_event(self, CyFCIO fcio):
    FCIOGetFSPEvent(fcio._fcio_data, &self._state)

  def read_fsp_status(self, CyFCIO fcio):
    # FCIOGetFSPStatus(fcio._fcio_data, &self._processor)
    pass

  @property
  def write_flags(self):
    return self._state.write_flags

  @property
  def proc_flags(self):
    return self._state.proc_flags

  @property
  def obs(self):
    return self._state.obs

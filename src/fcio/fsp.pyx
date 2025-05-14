from .def_fsp cimport StreamProcessor, FSPCreate, FSPDestroy
from .def_fsp cimport FCIOGetFSPConfig, FCIOGetFSPEvent, FCIOGetFSPStatus

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
    cdef numpy.ndarray _obs_ct_traceidx
    cdef numpy.ndarray _obs_ct_max
    cdef numpy.ndarray _obs_ps_hwm_prescaled_trace_idx

    cdef int _ct_size
    cdef int _hwm_size

  def __cinit__(self, FSP fsp):
    self._processor = fsp._processor

  def prepare(self):
    # array accessors
    cdef int[::1] obs_ct_traceidx_view = self._processor.fsp_state.obs.ct.trace_idx
    cdef unsigned short[::1] obs_ct_max_view = self._processor.fsp_state.obs.ct.max
    cdef unsigned short[::1] obs_ps_hwm_prescaled_trace_idx = self._processor.fsp_state.obs.ps.hwm_prescaled_trace_idx
    self._ct_size = self._processor.dsp_ct.tracemap.n_mapped
    self._hwm_size = self._processor.dsp_hwm.tracemap.n_mapped
    self._obs_ct_traceidx = numpy.ndarray(shape=(self._ct_size,), dtype=numpy.int32, offset=0, buffer=obs_ct_traceidx_view)
    self._obs_ct_max = numpy.ndarray(shape=(self._ct_size,), dtype=numpy.uint16, offset=0, buffer=obs_ct_max_view)
    self._obs_ps_hwm_prescaled_trace_idx = numpy.ndarray(shape=(self._hwm_size,), dtype=numpy.uint16, offset=0, buffer=obs_ps_hwm_prescaled_trace_idx)

  @property
  def write_flags(self):
    return self._processor.fsp_state.write_flags

  @property
  def proc_flags(self):
    return self._processor.fsp_state.proc_flags

  @property
  def obs(self):
    return self._processor.fsp_state.obs

  @property
  def is_written(self):
    return self._processor.fsp_state.write_flags.write

  @property
  def is_extended(self):
    return self._processor.fsp_state.write_flags.event.extended

  @property
  def is_consecutive(self):
    return self._processor.fsp_state.write_flags.event.consecutive

  @property
  def is_hwm_prescaled(self):
    return self._processor.fsp_state.write_flags.trigger.hwm_prescaled

  @property
  def is_hwm_multiplicity(self):
    return self._processor.fsp_state.write_flags.trigger.hwm_multiplicity

  @property
  def is_wps_sum(self):
    return self._processor.fsp_state.write_flags.trigger.wps_sum

  @property
  def is_wps_coincident_sum(self):
    return self._processor.fsp_state.write_flags.trigger.wps_coincident_sum

  @property
  def is_wps_prescaled(self):
    return self._processor.fsp_state.write_flags.trigger.wps_prescaled

  @property
  def is_ct_multiplicity(self):
    return self._processor.fsp_state.write_flags.trigger.ct_multiplicity

  @property
  def obs_wps_sum_value(self):
    return self._processor.fsp_state.obs.wps.sum_value
  @property
  def obs_wps_sum_offset(self):
    return self._processor.fsp_state.obs.wps.sum_offset
  @property
  def obs_wps_sum_multiplicity(self):
    return self._processor.fsp_state.obs.wps.sum_multiplicity
  @property
  def obs_wps_max_single_peak_value(self):
    return self._processor.fsp_state.obs.wps.max_single_peak_value
  @property
  def obs_wps_max_single_peak_offset(self):
    return self._processor.fsp_state.obs.wps.max_single_peak_offset
  @property
  def obs_hwm_hw_multiplicity(self):
    return self._processor.fsp_state.obs.hwm.hw_multiplicity
  @property
  def obs_hwm_sw_multiplicity(self):
    return self._processor.fsp_state.obs.hwm.sw_multiplicity
  @property
  def obs_hwm_max_value(self):
    return self._processor.fsp_state.obs.hwm.max_value
  @property
  def obs_hwm_min_value(self):
    return self._processor.fsp_state.obs.hwm.min_value
  @property
  def obs_ct_multiplicity(self):
    return self._processor.fsp_state.obs.ct.multiplicity
  @property
  def obs_ct_trace_idx(self):
    return self._obs_ct_traceidx[:self._processor.fsp_state.obs.ct.multiplicity]
  @property
  def obs_ct_max(self):
    return self._obs_ct_max[:self._processor.fsp_state.obs.ct.multiplicity]
  @property
  def obs_evt_nconsecutive(self):
    return self._processor.fsp_state.obs.evt.nconsecutive
  @property
  def obs_ps_hwm_prescaled_trace_idx(self):
    return self._obs_ps_hwm_prescaled_trace_idx[:self._processor.fsp_state.obs.ps.n_hwm_prescaled]


cdef class FSPStatus:
  cdef:
    StreamProcessor* _processor

  def __cinit__(self, FSP fsp):
    self._processor = fsp._processor

  @property
  def stats(self):
    """
    The internal c-struct exposed as python dictionary.
    """
    return self._processor.stats

  @property
  def start_time(self):
    return self._processor.stats.start_time

  @property
  def log_time(self):
    return self._processor.stats.log_time

  @property
  def dt_logtime(self):
    return self._processor.stats.dt_logtime

  @property
  def runtime(self):
    return self._processor.stats.runtime

  @property
  def n_read_events(self):
    return self._processor.stats.n_read_events

  @property
  def n_written_events(self):
    return self._processor.stats.n_written_events

  @property
  def n_discarded_events(self):
    return self._processor.stats.n_discarded_events

  @property
  def dt_n_read_events(self):
    return self._processor.stats.dt_n_read_events

  @property
  def dt_n_written_events(self):
    return self._processor.stats.dt_n_written_events

  @property
  def dt_n_discarded_events(self):
    return self._processor.stats.dt_n_discarded_events

  @property
  def dt(self):
    return self._processor.stats.dt

  @property
  def dt_rate_read_events(self):
    return self._processor.stats.dt_rate_read_events

  @property
  def dt_rate_write_events(self):
    return self._processor.stats.dt_rate_write_events

  @property
  def dt_rate_discard_events(self):
    return self._processor.stats.dt_rate_discard_events

  @property
  def avg_rate_read_events(self):
    return self._processor.stats.avg_rate_read_events

  @property
  def avg_rate_write_events(self):
    return self._processor.stats.avg_rate_write_events

  @property
  def avg_rate_discard_events(self):
    return self._processor.stats.avg_rate_discard_events


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
    # set array sizes
    self._event.prepare()

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

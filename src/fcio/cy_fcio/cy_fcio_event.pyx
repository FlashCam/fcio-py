from cfcio cimport fcio_event, fcio_config, FCIOMaxChannels

cimport numpy
import numpy

numpy.import_array()

cdef class CyEvent:
  cdef fcio_event *event_ptr
  cdef fcio_config *config_ptr
  
  # internal size trackers
  cdef int tracesamples
  cdef int maxtraces

  cdef numpy.ndarray _np_trace
  cdef numpy.ndarray _np_theader
  cdef numpy.ndarray _np_traces
  cdef numpy.ndarray _np_timestamp
  cdef numpy.ndarray _np_timeoffset
  cdef numpy.ndarray _np_deadregion
  cdef numpy.ndarray _np_trace_list

  def __cinit__(self, fcio : CyFCIO):
    # Functions exposed to python side do not allow cython objects as parameters.
    # We actually only need the underlying FCIOData pointer.

    self.event_ptr = &fcio._fcio_data.event
    self.config_ptr = &fcio._fcio_data.config

    # helper variables
    self.tracesamples = self.config_ptr.eventsamples + 2
    self.maxtraces = self.config_ptr.adcs + self.config_ptr.triggers

    # underlying buffer for trace and header information
    cdef unsigned short [:] traces_memview = fcio._fcio_data.event.traces

    shape = (self.maxtraces, self.config_ptr.eventsamples)
    self._np_trace = numpy.ndarray(shape=shape, dtype=numpy.uint16, offset=4, buffer=traces_memview)
    strides = ( (self.tracesamples)*self._np_trace.itemsize, self._np_trace.itemsize)
    self._np_trace = numpy.lib.stride_tricks.as_strided(self._np_trace, shape=shape, strides=strides, writeable=False)

    shape = (self.maxtraces, 2)
    self._np_theader = numpy.ndarray(shape=shape, dtype=numpy.uint16, offset=0, buffer=traces_memview)
    strides = ( (self.tracesamples)*self._np_theader.itemsize, self._np_theader.itemsize)
    self._np_theader = numpy.lib.stride_tricks.as_strided(self._np_theader, shape=shape, strides=strides, writeable=False)

    shape = (self.maxtraces, self.tracesamples)
    self._np_traces = numpy.ndarray(shape=shape, dtype=numpy.uint16, offset=0, buffer=traces_memview)
    strides = ( (self.tracesamples)*self._np_traces.itemsize, self._np_traces.itemsize)
    self._np_traces = numpy.lib.stride_tricks.as_strided(self._np_traces, shape=shape, strides=strides, writeable=False)
    
    cdef int[:] timestamp_memview = fcio._fcio_data.event.timestamp
    cdef int[:] timeoffset_memview = fcio._fcio_data.event.timeoffset
    cdef int[:] deadregion_memview = fcio._fcio_data.event.deadregion
    cdef unsigned short[:] trace_list_memview = fcio._fcio_data.event.trace_list

    self._np_timestamp = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=timestamp_memview)
    self._np_timeoffset = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=timeoffset_memview)
    self._np_deadregion = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=deadregion_memview)
    self._np_trace_list = numpy.ndarray(shape=(FCIOMaxChannels,), dtype=numpy.uint16, offset=0, buffer=trace_list_memview)

  cdef update(self):
    # Call this function if a new event has been read.
    # This updates the possible size changes
    self._np_timestamp = numpy.lib.stride_tricks.as_strided(self._np_timestamp, shape=(self.event_ptr.timestamp_size,), writeable=False)
    self._np_timeoffset = numpy.lib.stride_tricks.as_strided(self._np_timeoffset, shape=(self.event_ptr.timeoffset_size,), writeable=False)
    self._np_deadregion = numpy.lib.stride_tricks.as_strided(self._np_deadregion, shape=(self.event_ptr.deadregion_size,), writeable=False)
    self._np_trace_list = numpy.lib.stride_tricks.as_strided(self._np_trace_list, shape=(self.event_ptr.num_traces,), writeable=False)

  @property
  def type(self):
    return numpy.int32(self.event_ptr.type)

  @property
  def pulser(self):
    return numpy.float32(self.event_ptr.pulser)

  @property
  def timeoffset(self):
    return self._np_timeoffset

  @property
  def deadregion(self):
    return self._np_deadregion

  @property
  def timestamp(self):
    return self._np_timestamp

  @property
  def num_traces(self):
    return numpy.int32(self.event_ptr.num_traces)

  @property
  def trace_list(self):
    return self._np_trace_list

  @property
  def timeoffset_size(self):
    return numpy.int32(self.event_ptr.timeoffset_size)

  @property
  def timestamp_size(self):
    return numpy.int32(self.event_ptr.timestamp_size)

  @property
  def deadregion_size(self):
    return numpy.int32(self.event_ptr.deadregion_size)

  @property
  def trace_buffer(self):
    return self._np_traces

  @property
  def trace(self):
    return self._np_trace

  @property
  def theader(self):
    return self._np_theader

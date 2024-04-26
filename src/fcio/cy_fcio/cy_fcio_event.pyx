from cfcio cimport fcio_event, fcio_config, FCIOMaxChannels

cimport numpy
import numpy

numpy.import_array()

cdef class CyEvent:
  """
  Class internal to the fcio library. Do not allocate directly, must be created by using `fcio_open` or 
  FCIO.open().
  Exposes the fcio_event struct fields from the fcio.c library.
  All fields are exposes as numpy scalars or arrays with their corresponsing datatype and size.
  """
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
    pass

  @property
  def type(self):
    """
    the event type
    """
    return numpy.int32(self.event_ptr.type)

  @property
  def pulser(self):
    """
    the pulser amplitude setting
    """
    return numpy.float32(self.event_ptr.pulser)

  @property
  def timeoffset(self):
    """
    the offset between master card pps/clock counters and the readout server unix time.
    """
    return self._np_timeoffset[:self.event_ptr.timeoffset_size]

  @property
  def deadregion(self):
    """
    the pps/clock counters while the readout system buffers are full.
    only updates when the system is 
    """
    return self._np_deadregion[:self.event_ptr.deadregion_size]

  @property
  def timestamp(self):
    """
    contains event counters and pps/clock counters
    """
    return self._np_timestamp[:self.event_ptr.timestamp_size]

  @property
  def num_traces(self):
    """
    the numbers of traces contain in the event.
    Incase of FCIOTag.Event tag, num_traces must be equal to the total number of mapped channels.
    """
    return numpy.int32(self.event_ptr.num_traces)

  @property
  def trace_list(self):
    """
    Lookup array for the mapped channels, use with trace_buffer or trace attributes to get the
    correct waveforms.
    """
    return self._np_trace_list[:self.event_ptr.num_traces]

  @property
  def timeoffset_size(self):
    """
    Size of the timeoffset array. 
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self.event_ptr.timeoffset_size)

  @property
  def timestamp_size(self):
    """
    Size of the timestamp array. 
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self.event_ptr.timestamp_size)

  @property
  def deadregion_size(self):
    """
    Size of the deadregion array. 
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self.event_ptr.deadregion_size)

  @property
  def trace_buffer(self):
    """
    The internal 2D FCIO traces buffer.
    Exposed for faster read operations, e.g. using memcpy or remapping of the buffer.
    For waveform acces, use the `trace` property.
    shape is (<total number of mapped trace>,<number of samples + 2>)
    """
    return self._np_traces

  @property
  def trace(self):
    """
    2D array of the waveforms.
    shape is (<total number of mapped trace>,<number of samples>)
    """
    return self._np_trace

  @property
  def theader(self):
    """
    2D array of the waveforms headers containing the [0]fpga baseline and [1]fpga energy.
    shape is (<total number of mapped trace>,<2>)
    """
    return self._np_theader

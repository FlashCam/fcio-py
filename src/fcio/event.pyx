from .def_fcio cimport fcio_event, fcio_config, FCIOMaxChannels

cimport numpy
import numpy

numpy.import_array()

cdef class Event(FCIOHeaderExt):
  """
  Class internal to the fcio library. Do not allocate directly, must be created by using `fcio_open` or
  FCIO.open().
  Exposes the fcio_event struct fields from the fcio.c library.
  All fields are exposes as numpy scalars or arrays with their corresponsing datatype and size.
  """
  cdef fcio_event *_event_ptr

  # internal size trackers
  cdef int tracesamples

  cdef numpy.ndarray _np_trace
  cdef numpy.ndarray _np_theader
  cdef numpy.ndarray _np_traces
  cdef numpy.ndarray _np_timestamp
  cdef numpy.ndarray _np_timeoffset
  cdef numpy.ndarray _np_deadregion
  cdef numpy.ndarray _np_trace_list

  def __cinit__(self, fcio : FCIO):
    # Functions exposed to python side do not allow cython objects as parameters.
    # We actually only need the underlying FCIOData pointer.

    self._event_ptr = &fcio._fcio_data.event

    # helper variables
    self.tracesamples = self._config_ptr.eventsamples + 2

    # underlying buffer for trace and header information
    cdef unsigned short [::1] traces_memview = fcio._fcio_data.event.traces

    shape = (self._maxtraces, self._config_ptr.eventsamples)
    self._np_trace = numpy.ndarray(shape=shape, dtype=numpy.uint16, offset=4, buffer=traces_memview)
    strides = ( (self.tracesamples)*self._np_trace.itemsize, self._np_trace.itemsize)
    self._np_trace = numpy.lib.stride_tricks.as_strided(self._np_trace, shape=shape, strides=strides, writeable=False)

    shape = (self._maxtraces, 2)
    self._np_theader = numpy.ndarray(shape=shape, dtype=numpy.uint16, offset=0, buffer=traces_memview)
    strides = ( (self.tracesamples)*self._np_theader.itemsize, self._np_theader.itemsize)
    self._np_theader = numpy.lib.stride_tricks.as_strided(self._np_theader, shape=shape, strides=strides, writeable=False)

    shape = (self._maxtraces, self.tracesamples)
    self._np_traces = numpy.ndarray(shape=shape, dtype=numpy.uint16, offset=0, buffer=traces_memview)
    strides = ( (self.tracesamples)*self._np_traces.itemsize, self._np_traces.itemsize)
    self._np_traces = numpy.lib.stride_tricks.as_strided(self._np_traces, shape=shape, strides=strides, writeable=False)

    cdef int[::1] timestamp_memview = fcio._fcio_data.event.timestamp
    cdef int[::1] timeoffset_memview = fcio._fcio_data.event.timeoffset
    cdef int[::1] deadregion_memview = fcio._fcio_data.event.deadregion
    cdef unsigned short[::1] trace_list_memview = fcio._fcio_data.event.trace_list

    self._np_timestamp = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=timestamp_memview)
    self._np_timeoffset = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=timeoffset_memview)
    self._np_deadregion = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=deadregion_memview)
    self._np_trace_list = numpy.ndarray(shape=(FCIOMaxChannels,), dtype=numpy.uint16, offset=0, buffer=trace_list_memview)

  @property
  def type(self):
    """
    the event type
    """
    return numpy.int32(self._event_ptr.type)

  @property
  def pulser(self):
    """
    the pulser amplitude setting
    """
    return numpy.float32(self._event_ptr.pulser)

  @property
  def timeoffset(self):
    """
    the offset between master card pps/clock counters and the readout server unix time.
    """
    return self._np_timeoffset[:self._event_ptr.timeoffset_size]

  @property
  def deadregion(self):
    """
    the pps/clock counters while the readout system buffers are full.
    only updates when the system is
    """
    return self._np_deadregion[:self._event_ptr.deadregion_size]

  @property
  def timestamp(self):
    """
    contains event counters and pps/clock counters
    """
    return self._np_timestamp[:self._event_ptr.timestamp_size]

  @property
  def num_traces(self):
    """
    the numbers of traces contain in the event.
    Incase of FCIOTag.Event tag, num_traces must be equal to the total number of mapped channels.
    """
    return numpy.int32(self._event_ptr.num_traces)

  @property
  def trace_list(self):
    """
    Lookup array for the mapped channels, use with trace_buffer or trace attributes to get the
    correct waveforms.
    """
    return self._np_trace_list[:self._event_ptr.num_traces]

  @property
  def timeoffset_size(self):
    """
    Size of the timeoffset array.
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self._event_ptr.timeoffset_size)

  @property
  def timestamp_size(self):
    """
    Size of the timestamp array.
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self._event_ptr.timestamp_size)

  @property
  def deadregion_size(self):
    """
    Size of the deadregion array.
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self._event_ptr.deadregion_size)

  @property
  def trace_buffer(self):
    """
    The internal 2D FCIO traces buffer.
    Exposed for faster read operations, e.g. using memcpy or remapping of the buffer.
    For waveform access, use the `trace` property.
    shape is (<total number of mapped trace>,<number of samples + 2>)
    """
    return self._np_traces

  @property
  def trace(self):
    """
    2D array containing the waveforms.
    shape is (<total number of traces in this event>,<number of samples>).
    See trace_list to get the correct trace_index or card_address / card_channel attributes.
    """
    if self._tag == FCIOTag.FCIOEventHeader:
      return self._np_trace[[]]

    return self._np_trace[self.trace_list]

  @property
  def theader(self):
    """
    2D array of the waveforms headers containing the [0]fpga baseline and [1] fpga energy.
    shape is (<total number of traces in this event>,<2>)
    """
    return self._np_theader[self.trace_list]

  @property
  def fpga_baseline(self):
    """
    1-d array of fpga baseline values with length <total number of read out traces>.
    """
    return self._np_theader[self.trace_list,0] / self._config_ptr.blprecision

  @property
  def fpga_energy(self):
    """
    1-d array of fpga energy values with length <total number of read out traces>.
    """
    if self._config_ptr.adcbits == 12: #250MHz
      return self._config_ptr.sumlength / self._config_ptr.blprecision * (self._np_theader[self.trace_list,1] - self._np_theader[self.trace_list,0])
    elif self._config_ptr.adcbits == 16: #62.5MHz
      return self._np_theader[self.trace_list,1]

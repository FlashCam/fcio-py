from .def_fcio cimport fcio_recevent, fcio_config, FCIOMaxPulses

cimport numpy
import numpy

numpy.import_array()

cdef class RecEvent(FCIOHeaderExt):
  """
  Class internal to the fcio library. Do not allocate directly, must be created by using `fcio_open` or
  FCIO.open().
  Exposes the fcio_event struct fields from the fcio.c library.
  All fields are exposes as numpy scalars or arrays with their corresponsing datatype and size.
  """
  cdef fcio_recevent *_recevent_ptr

  cdef numpy.ndarray _np_channel_pulses
  cdef numpy.ndarray _np_flags
  cdef numpy.ndarray _np_times
  cdef numpy.ndarray _np_amplitudes
  cdef numpy.ndarray _np_timestamp
  cdef numpy.ndarray _np_timeoffset
  cdef numpy.ndarray _np_deadregion

  def __cinit__(self, fcio : FCIO):
    # Functions exposed to python side do not allow cython objects as parameters.
    # We actually only need the underlying FCIOData pointer.

    self._recevent_ptr = &fcio._fcio_data.recevent

    cdef int [::1] channel_pulses_memview = fcio._fcio_data.recevent.channel_pulses
    cdef int [::1] flags_memview = fcio._fcio_data.recevent.flags
    cdef float [::1] times_memview = fcio._fcio_data.recevent.times
    cdef float [::1] amplitudes_memview = fcio._fcio_data.recevent.amplitudes

    self._np_channel_pulses = numpy.ndarray(shape=(self._maxtraces, ), dtype=numpy.int32, offset=0, buffer=channel_pulses_memview)
    self._np_flags = numpy.ndarray(shape=(FCIOMaxPulses, ), dtype=numpy.int32, offset=0, buffer=flags_memview)
    self._np_times = numpy.ndarray(shape=(FCIOMaxPulses, ), dtype=numpy.float32, offset=0, buffer=times_memview)
    self._np_amplitudes = numpy.ndarray(shape=(FCIOMaxPulses, ), dtype=numpy.float32, offset=0, buffer=amplitudes_memview)

    cdef int[::1] timestamp_memview = fcio._fcio_data.recevent.timestamp
    cdef int[::1] timeoffset_memview = fcio._fcio_data.recevent.timeoffset
    cdef int[::1] deadregion_memview = fcio._fcio_data.recevent.deadregion

    self._np_timestamp = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=timestamp_memview)
    self._np_timeoffset = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=timeoffset_memview)
    self._np_deadregion = numpy.ndarray(shape=(10,), dtype=numpy.int32, offset=0, buffer=deadregion_memview)

  @property
  def type(self):
    """
    the event type
    """
    return numpy.int32(self._recevent_ptr.type)

  @property
  def pulser(self):
    """
    the pulser amplitude setting
    """
    return numpy.float32(self._recevent_ptr.pulser)

  @property
  def timeoffset(self):
    """
    the offset between master card pps/clock counters and the readout server unix time.
    """
    return self._np_timeoffset[:self._recevent_ptr.timeoffset_size]

  @property
  def deadregion(self):
    """
    the pps/clock counters while the readout system buffers are full.
    only updates when the system is
    """
    return self._np_deadregion[:self._recevent_ptr.deadregion_size]

  @property
  def timestamp(self):
    """
    contains event counters and pps/clock counters
    """
    return self._np_timestamp[:self._recevent_ptr.timestamp_size]

  @property
  def timeoffset_size(self):
    """
    Size of the timeoffset array.
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self._recevent_ptr.timeoffset_size)

  @property
  def timestamp_size(self):
    """
    Size of the timestamp array.
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self._recevent_ptr.timestamp_size)

  @property
  def deadregion_size(self):
    """
    Size of the deadregion array.
    Must be equal to the shape[0] of the array.
    """
    return numpy.int32(self._recevent_ptr.deadregion_size)

  @property
  def totalpulses(self):
    """
    The total number of pulses in this RecEvent.
    Determines the size of the `flags`,`times` and `amplitudes` fields.
    """
    return numpy.int32(self._recevent_ptr.totalpulses)

  @property
  def channel_pulses(self):
    """
    A list of pulses per channel.
    Size is number of adcs (in config record).
    Use to look up the pulses per channel in the `flags`,`times` and `amplitudes` fields.
    """
    return self._np_channel_pulses

  @property
  def flags(self):
    """
    An int32 array containing some flags.
    """
    return self._np_flags[:self.totalpulses]

  @property
  def times(self):
    """
    An float32 field containing the reconstructed times of the pulses.
    """
    return self._np_times[:self.totalpulses]

  @property
  def amplitudes(self):
    """
    An float32 field containing the reconstructed amplitudes of the pulses.
    """
    return self._np_amplitudes[:self.totalpulses]

  @property
  def pulses(self):
    """
    Accessor for the stored pulse properties, will yield a tuple
    (trace_idx, flag, time, amplitude).
    """
    cdef int offset = 0
    cdef int npulses, i
    for i in range(self._maxtraces):
      npulses = self._recevent_ptr.channel_pulses[i]
      if npulses > 0:
        yield (i,
          self._np_flags[offset:offset+npulses],
          self._np_times[offset:offset+npulses],
          self._np_amplitudes[offset:offset+npulses]
        )
        offset += npulses

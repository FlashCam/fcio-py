cimport numpy
import numpy

from .def_fcio cimport FCIOMaxChannels

cdef class DeadIntervalBuffer():
  # maximum interval buffer size
  # is given by the maximum number of events
  # storable in the hardware
  DEF FC_MAX_EVENTS = 2048
  cdef long[FCIOMaxChannels][FC_MAX_EVENTS] interval_begin
  cdef long[FCIOMaxChannels][FC_MAX_EVENTS] interval_end
  cdef int[FCIOMaxChannels] current_write
  cdef int[FCIOMaxChannels] current_read
  cdef int[FCIOMaxChannels] fill

  cdef numpy.ndarray current_interval

  def __cinit__(self):
    for i in range(FCIOMaxChannels):
      self.current_write[i] = FC_MAX_EVENTS-1
      self.current_read[i] = 0
      self.fill[i] = 0
      for j in range(FC_MAX_EVENTS):
        if (self.interval_begin[i][j] != 0):
          print("not zero")
      #  self.interval_end[i][j] = 0

    self.current_interval = numpy.zeros((FCIOMaxChannels,), dtype=numpy.int64)

  def __dealloc__(self):
    pass

  cdef add(self, long interval_start, long interval_stop, int trace_idx_start, int ntraces):
    cdef int add_slot
    cdef int trace_idx
    for offset in range(ntraces):
      trace_idx = trace_idx_start + offset
      if self.fill[trace_idx] >= FC_MAX_EVENTS:
        raise ValueError("ERROR fcio-py: dead-time buffer full, requires source code updates with new defines to change.")
      add_slot = self.current_write[trace_idx]
      if interval_stop > self.interval_end[trace_idx][add_slot]:
        add_slot = (add_slot + 1) % FC_MAX_EVENTS
        self.fill[trace_idx] += 1

        self.interval_begin[trace_idx][add_slot] = interval_start
        self.interval_end[trace_idx][add_slot] = interval_stop
        self.current_write[trace_idx] = add_slot

      #   print(f"DEBUG DeadIntervalTracker/add: trace {trace_idx} write slot {add_slot} fill level {self.fill[trace_idx]} entry {interval_start} {interval_stop} delta {interval_stop - interval_start} previous {self.interval_end[trace_idx][add_slot-1]}")
      # else:
      #   print(f"DEBUG DeadIntervalTracker/add: trace {trace_idx} write slot {add_slot+1} skip entry {interval_start} {interval_stop} delta {interval_stop - interval_start} previous {self.interval_end[trace_idx][add_slot]}")

  cdef is_before(self, long timestamp_ns, int trace_idx_start, int ntraces):
    cdef int read_slot
    cdef int trace_idx
    for offset in range(ntraces):
      trace_idx = trace_idx_start + offset
      if self.fill[trace_idx] == 0:
        # print(f"DEBUG DeadIntervalTracker/is_before: trace {trace_idx} empty.")
        return False
      read_slot = self.current_read[trace_idx]
      # print(f"DEBUG DeadIntervalTracker/is_before: /trace {trace_idx} read slot {read_slot} fill level {self.fill[trace_idx]} {self.interval_end[trace_idx][read_slot]} <= {timestamp_ns} : {self.interval_end[trace_idx][read_slot] <= timestamp_ns}")
      # if self.interval_end[trace_idx][read_slot] <= timestamp_ns:
      if timestamp_ns - self.interval_end[trace_idx][read_slot] > -4:
      # an overlap of 3 nanoseconds is allowed, as the 16bit firmware might read the stamps during the sampling of a 16ns window. This should not affect the 12bit firmware.
        return True
    return False

  cdef read(self, int trace_idx_start, int ntraces):
    cdef int read_slot
    cdef int trace_idx

    for offset in range(ntraces):
      trace_idx = trace_idx_start + offset
      read_slot = self.current_read[trace_idx]
      if self.fill[trace_idx] > 0:
        self.current_interval[offset] = self.interval_end[trace_idx][read_slot] - self.interval_begin[trace_idx][read_slot]
        self.current_read[trace_idx] = (self.current_read[trace_idx] + 1 ) % FC_MAX_EVENTS
        self.fill[trace_idx] -= 1
        # print(f"DEBUG DeadIntervalTracker/read: trace {trace_idx} read slot {read_slot} fill level {self.fill[trace_idx]} entry {self.interval_begin[trace_idx][read_slot]} {self.interval_end[trace_idx][read_slot]} delta {self.interval_end[trace_idx][read_slot] -self.interval_begin[trace_idx][read_slot]}")
      else:
        raise ValueError(f"ERROR fcio-py: trying to read a dead-time interval from empty buffer.")

    return self.current_interval[:ntraces]

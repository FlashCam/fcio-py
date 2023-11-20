"""we use numpy"""
import numpy as np

def ppsticks2sec(pps : int, ticks : int, maxticks : int):
  """Converts FCIO timestamp fields into a floating point in seconds

  Args:
      pps (int): timestamp[1]
      ticks (int): timestamp[2]
      maxticks (int): timetamp[3]

  Returns:
      float: the ticks counter converted to seconds in float.
  """
  return (pps*maxticks+ticks)/maxticks

class Event:
  """Wraps the Event and SparseEvent tag field into a python class.
  """
  def __init__(self, raw_event_struct, config):
    self.buffer = raw_event_struct
    self.config = config
    self.nadcs = self.config.nadcs
    self.nsamples = self.config.nsamples
    self.ntriggers = self.config.ntriggers

    # internal accessors
    self._baseline = np.ndarray(buffer=self.buffer.traces,
                                dtype=np.uint16,
                                shape=(self.nadcs, ),
                                offset=0,
                                strides=((self.nsamples+2) * 2,))
    self._baseline.setflags(write=False)

    self._integrator = np.ndarray(buffer=self.buffer.traces,
                                  dtype=np.uint16,
                                  shape=(self.nadcs, ),
                                  offset=2,
                                  strides=((self.nsamples+2) * 2,))
    self._integrator.setflags(write=False)

    self._traces = np.ndarray(buffer=self.buffer.traces,
                              dtype=np.uint16,
                              shape=(self.nadcs, self.nsamples),
                              offset=4,
                              strides=((self.nsamples+2) * 2, 2))
    self._traces.setflags(write=False)

    self._triggertraces = np.ndarray(buffer=self.buffer.traces,
                                     dtype=np.uint16,
                                     shape=(self.config.ntriggers, self.nsamples),
                                     offset=((self.nsamples+2) * self.nadcs) * 2 + 4,
                                     strides=((self.nsamples+2) * 2, 2))
    self._triggertraces.setflags(write=False)

    # keeping track of total dead-time
    self.last_dtstop = 0
    self.total_dt = 0

  @property
  def numtraces(self):
    """The number of traces actually present in this event.

    Returns:
        int: the number of traces present in the event.
    """
    return self.buffer.num_traces

  @property
  def tracelist(self):
    """
    Returns the list of triggered adcs for the current event
    return np.ndarray(shape=(self.nadcs), dtype=np.int, buffer=tracelist_view)
    """
    return np.ndarray(shape=(self.numtraces), dtype=np.uint16, buffer=self.buffer.trace_list)

  @property
  def traces(self):
    """
    Returns an numpy array with a view set to the data fields in the traces array of the FCIOData struct.
    """
    return self._traces[:self.numtraces]

  @property
  def triggertraces(self):
    """
    Returns an numpy array with a view set to the triggersum fields in the traces array of the FCIOData struct.
    """
    if self.numtraces != self.nadcs:
      raise Exception("Trying to access the trigger traces while reading a FCIOSparseEvent, which don't contain trigger traces.")
    return self._triggertraces

  @property
  def fpga_baselines(self):
    # if adcbits == 16 then blprecision is 1, so it should always work
    return self._baseline[:self.numtraces] / self.config.blprecision

  @property
  def fpga_energies(self):
    if self.config.adcbits == 12:
      return (self._integrator[:self.numtraces] - self._baseline[:self.numtraces]) * (self.config.sumlength / self.config.blprecision)
    elif self.config.adcbits == 16:
      return self._integrator[:self.numtraces]

  # alias
  fpga_integrals = fpga_energies

  def get_trace(self, adc_channel_index : int = None, adc_channel_map : int = None, card_address : int = None, card_channel : int = None):
    """_summary_

    Yields:
        _type_: _description_
    """
    if adc_channel_index:
      # np.searchsorted(self.tracelist, adc_channel_index)+1
      it = np.where(self.tracelist == adc_channel_index)[0]

    elif adc_channel_map:
      it = np.where(self.config.tracemap == adc_channel_map)[0]

    elif card_address and card_channel:
      it = np.where(self.config.tracemap == ((card_address << 16) + card_channel))[0]

    if (len(it) > 0):
      return self.traces[it]
    else:
      return None

  @property
  def get_traces(self):
    for it in range(self.numtraces):
      trace_index = self.tracelist[it]
      card_address = self.config.card_addresses[it]
      card_channel = self.config.card_channels[it]
      fpga_energy = self.fpga_energies[it]
      fpga_baseline = self.fpga_baselines[it]
      yield (trace_index, card_address, card_channel, fpga_baseline, fpga_energy, self.traces[it])

  @property
  def pulser(self):
    return self.buffer.pulser

  @property
  def type(self):
    return self.buffer.type

  @property
  def last_sample_period_ns(self):
    return 1 / (self.timestamp_maxticks + 1) * 1e9

  @property
  def runtime_ns(self):
    sample_period = 1 / (self.timestamp_maxticks + 1) * 1e9
    event_ns = np.int64(self.timestamp_ticks * sample_period)
    start_time_ns = self.buffer.timeoffset[5] *1e9 + self.buffer.timeoffset[6] * 1e3 # not as precise
    return np.int64(self.timestamp_pps * 1e9) + event_ns - start_time_ns

  @property
  def runtime_sec(self):
    return self.runtime_ns * 1e-9

  @property
  def eventtime_ns(self):
    if self.config.gps == 0:
      offset_to_add = np.int64(self.buffer.timeoffset[0]) * 1e9 + np.int64(self.buffer.timeoffset[1]) * 1e3
    elif self.config.gps > 0:
      offset_to_add = np.int64(self.buffer.timeoffset[2]) * 1e9
    return self.runtime_ns + offset_to_add

  @property
  def eventtime_sec(self):
    return self.eventtime_ns * 1e-9

  @property
  def eventnumber(self):
    return self.buffer.timestamp[0]

  @property
  def timestamp_pps(self):
    return self.buffer.timestamp[1]

  @property
  def timestamp_ticks(self):
    return self.buffer.timestamp[2]

  @property
  def timestamp_maxticks(self):
    return self.buffer.timestamp[3]

  """
    fcio_event 'timeoffset' fields
  """

  @property
  def timeoffset_mu_sec(self):
    return self.buffer.timeoffset[0]

  @property
  def timeoffset_mu_usec(self):
    return self.buffer.timeoffset[1]

  @property
  def timeoffset_master_sec(self):
    return self.buffer.timeoffset[2]

  @property
  def timeoffset_dt_mu_usec(self):
    return self.buffer.timeoffset[3]

  @property
  def timeoffset_abs_mu_usec(self):
    return self.buffer.timeoffset[4]

  @property
  def timeoffset_start_sec(self):
    return self.buffer.timeoffset[5]

  @property
  def timeoffset_start_usec(self):
    return self.buffer.timeoffset[6]

  """
    fcio_event 'deadregion' fields
  """

  @property
  def deadregion_start_pps(self):
    return self.buffer.deadregion[0]

  @property
  def deadregion_start_ticks(self):
    return self.buffer.deadregion[1]

  @property
  def deadregion_stop_pps(self):
    return self.buffer.deadregion[2]

  @property
  def deadregion_stop_ticks(self):
    return self.buffer.deadregion[3]

  @property
  def deadregion_maxticks(self):
    return self.buffer.deadregion[4]

  @property
  def deadregion_index_start(self):
    return self.buffer.deadregion[5]

  @property
  def deadregion_index_stop(self):
    return self.buffer.deadregion[6]

  @property
  def deadtime(self):
    dtstart_sec = ppsticks2sec(self.buffer.deadregion[0], self.buffer.deadregion[1], self.buffer.deadregion[4])
    dtstop_sec = ppsticks2sec(self.buffer.deadregion[2], self.buffer.deadregion[3], self.buffer.deadregion[4])
    if dtstop_sec > self.last_dtstop:
      self.last_dtstop = dtstop_sec
      dt_delta = dtstop_sec - dtstart_sec
      self.total_dt += dt_delta
      return (dt_delta, self.total_dt)
    else:
      return (0, self.total_dt)

  # @property
  # def deadtime_sec(self):
  #   return (self.deadregion_stop_pps-self.deadregion_start_pps) + (self.deadregion_stop_ticks-self.deadregion_start_ticks)/(self.deadregion_maxticks+1)

  # @property
  # def deadtime_ns(self):
  #   sample_period = 1 / (self.deadregion_maxticks + 1) * 1e9
  #   deadtime_ns = (self.deadregion_stop_ticks-self.deadregion_start_ticks) * sample_period
  #   return np.int64(self.deadregion_stop_pps-self.deadregion_start_pps) + np.int64(deadtime_ns)


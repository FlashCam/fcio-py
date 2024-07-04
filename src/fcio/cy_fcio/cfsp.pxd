from numpy cimport uint8_t, uint64_t

cdef extern from "fsp/io.h":
  # Forward Decl
  ctypedef struct FCIOData:
    pass

  void FCIOGetFSPConfig(FCIOData* input, StreamProcessor* processor)
  void FCIOGetFSPEvent(FCIOData* input, FSPState* fsp_state)
  void FCIOGetFSPStatus(FCIOData* input, StreamProcessor* processor)

  void FSPFreeStreamProcessor(StreamProcessor* processor)
  StreamProcessor* FSPCallocStreamProcessor()

cdef extern from "fsp/state.h":

  # defines in fcio.h
  cdef const int FCIOMaxChannels
  cdef const int FCIOMaxSamples
  cdef const int FCIOMaxPulses
  cdef const int FCIOTraceBufferLength

  ### Write Flags
  ctypedef union STFlags:
    uint8_t hwm_multiplicity  # the multiplicity threshold has been reached
    uint8_t hwm_prescaled  # the event was prescaled due to the HWM condition
    uint8_t wps_abs  # the absolute peak sum threshold was reached
    uint8_t wps_rel  # the relative peak sum threshold was reached and a coincidence to a reference event is fulfilled
    uint8_t wps_prescaled  # the event was prescaled due to the WPS condition
    uint8_t ct_multiplicity  # a channel was above the ChannelThreshold condition

    uint64_t is_flagged


  ctypedef union EventFlags:
    uint8_t is_retrigger  # the event is a retrigger event
    uint8_t is_extended  # the event triggered (a) retrigger event(s)

    uint64_t is_flagged
  ctypedef struct FSPWriteFlags:
    EventFlags event
    STFlags trigger
    int write

  ### Proc Flags
  ctypedef union WPSFlags:
    uint8_t abs_threshold  # absolute threshold was reached
    uint8_t rel_threshold  # relative threshold was reached
    uint8_t rel_reference  # the event is a WPS reference event
    uint8_t rel_pre_window  # the event is in the pre window of a reference event
    uint8_t rel_post_window  # the event is in the post window of a reference event
    uint8_t prescaled  # in addition to the multiplicity_below condition the current event is ready to prescale to it's timestamp

    uint64_t is_flagged

  ctypedef union HWMFlags:
    uint8_t multiplicity_threshold  # the multiplicity threshold (number of channels) has been reached
    uint8_t multiplicity_below  # all non-zero channels have an hardware value below the set amplitude threshold
    uint8_t prescaled  # in addition to the multiplicity_below condition the current event is ready to prescale to it's timestamp

    uint64_t is_flagged

  ctypedef union CTFlags:
    uint8_t multiplicity  # if number of threshold triggers > 0

    uint64_t is_flagged

  ctypedef struct FSPProcessorFlags:
    HWMFlags hwm
    WPSFlags wps
    CTFlags ct

  ### Observables
  ctypedef struct wps_obs:
    float max_value  # what is the maximum PE within the integration windows
    int max_offset  # when is the total sum offset reached?
    int max_multiplicity  # How many channels did have a peak above thresholds
    float max_single_peak_value  # which one was the largest individual peak
    int max_single_peak_offset  # which sample contains this peak

  ctypedef struct hwm_obs:
    int multiplicity  # how many channels have fpga_energy > 0
    unsigned short max_value  # what is the largest fpga_energy of those
    unsigned short min_value  # what is the smallest fpga_energy of those

  ctypedef struct ct_obs:
    int multiplicity  # how many channels were above the threshold
    int trace_idx[FCIOMaxChannels]  # the corresponding fcio trace index
    unsigned short max[FCIOMaxChannels]  # the maximum per channel
    # const char* label[FCIOMaxChannels]  # the name of the channel given during setup

  ctypedef struct evt_obs:
    int nextension  # if we found re-triggers how many events are consecutive from then on. the event with the extension flag carries the total number

  ctypedef struct SubEventList:
    int size
    int start[FCIOMaxSamples]
    int stop[FCIOMaxSamples] # first sample after trigger up is gone
    float wps_max[FCIOMaxSamples]

  ctypedef struct FSPObservables:
    wps_obs wps
    hwm_obs hwm
    ct_obs ct
    evt_obs evt
    SubEventList sub_event_list

  ### Tie everthing together in the state struct
  ctypedef struct FSPState:
    # ommits FSP internal fields here, see "fsp_state.h" for the full definition
    FSPWriteFlags write_flags
    FSPProcessorFlags proc_flags
    FSPObservables obs


  ### FSPConfig / FSPStatus
  ctypedef struct Timestamp:
    long seconds
    long nanoseconds


  ctypedef struct FSPConfig:
    int hwm_threshold
    int hwm_prescale_ratio
    int wps_prescale_ratio
    int muon_coincidence

    float relative_wps_threshold
    float absolute_wps_threshold
    float wps_prescale_rate
    float hwm_prescale_rate

    HWMFlags wps_reference_flags_hwm
    CTFlags wps_reference_flags_ct
    WPSFlags wps_reference_flags_wps

    FSPWriteFlags enabled_flags
    Timestamp pre_trigger_window
    Timestamp post_trigger_window


  ctypedef struct WindowedPeakSumConfig:
    int tracemap[FCIOMaxChannels]
    float gains[FCIOMaxChannels]
    float thresholds[FCIOMaxChannels]
    float lowpass[FCIOMaxChannels]
    int shaping_widths[FCIOMaxChannels]
    int dsp_pre_samples[FCIOMaxChannels]
    int dsp_post_samples[FCIOMaxChannels]
    int dsp_start_sample[FCIOMaxChannels]
    int dsp_stop_sample[FCIOMaxChannels]
    int dsp_pre_max_samples
    int dsp_post_max_samples
    int ntraces

    int apply_gain_scaling

    int coincidence_window
    int sum_window_start_sample
    int sum_window_stop_sample
    float coincidence_threshold

  ctypedef struct HardwareMajorityConfig:
    int ntraces
    int tracemap[FCIOMaxChannels]
    unsigned short fpga_energy_threshold_adc[FCIOMaxChannels]

  ctypedef struct ChannelThresholdConfig:
    int ntraces
    int tracemap[FCIOMaxChannels]
    unsigned short thresholds[FCIOMaxChannels]
    # const char* labels[FCIOMaxChannels]

  ctypedef struct FSPStats:
    double start_time
    double log_time
    double dt_logtime
    double runtime

    int n_read_events
    int n_written_events
    int n_discarded_events

    int dt_n_read_events
    int dt_n_written_events
    int dt_n_discarded_events

    double dt
    double dt_rate_read_events
    double dt_rate_write_events
    double dt_rate_discard_events

    double avg_rate_read_events
    double avg_rate_write_events
    double avg_rate_discard_events

  ctypedef struct FSPBuffer:
    int max_states
    Timestamp buffer_window

  ctypedef struct StreamProcessor:
    FSPConfig config
    FSPBuffer* buffer

    WindowedPeakSumConfig *wps_cfg
    HardwareMajorityConfig *hwm_cfg
    ChannelThresholdConfig *ct_cfg
    FSPStats* stats

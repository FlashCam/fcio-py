from numpy cimport uint8_t, uint64_t

cdef extern from "fsp.h":
  # Forward Decl
  ctypedef struct FCIOData:
    pass

  void FCIOGetFSPConfig(FCIOData* input, StreamProcessor* processor)
  void FCIOGetFSPEvent(FCIOData* input, StreamProcessor* processor)
  void FCIOGetFSPStatus(FCIOData* input, StreamProcessor* processor)

  StreamProcessor *FSPCreate(unsigned int buffer_depth)
  void FSPDestroy(StreamProcessor *processor)

  # defines in fcio.h
  cdef const int FCIOMaxChannels
  cdef const int FCIOMaxSamples
  cdef const int FCIOMaxPulses
  cdef const int FCIOTraceBufferLength

  ### Write Flags
  ctypedef union TriggerFlags:
    uint8_t hwm_multiplicity  # the multiplicity threshold has been reached
    uint8_t hwm_prescaled  # the event was prescaled due to the HWM condition
    uint8_t wps_sum # the standalone peak sum threshold was reached
    uint8_t wps_coincident_sum # the coincidence peak sum threshold was reached and a coincidence to a reference event is fulfilled
    uint8_t wps_prescaled  # the event was prescaled due to the WPS condition
    uint8_t ct_multiplicity  # a channel was above the ChannelThreshold condition

    uint64_t is_flagged


  ctypedef union EventFlags:
    uint8_t consecutive # the event might be a retrigger event or start immediately after
    uint8_t extended # the event preceeds one or more consecutive events

    uint64_t is_flagged

  ctypedef struct FSPWriteFlags:
    EventFlags event
    TriggerFlags trigger
    int write

  ### Proc Flags
  ctypedef union WPSFlags:
    uint8_t sum_threshold  # absolute threshold was reached
    uint8_t coincidence_sum_threshold  # relative threshold was reached
    uint8_t coincidence_ref  # the event is a WPS reference event
    uint8_t ref_pre_window  # the event is in the pre window of a reference event
    uint8_t ref_post_window  # the event is in the post window of a reference event
    uint8_t prescaled  # in addition to the multiplicity_below condition the current event is ready to prescale to it's timestamp

    uint64_t is_flagged

  ctypedef union HWMFlags:
    uint8_t sw_multiplicity  # the multiplicity threshold (number of channels) has been reached in sw
    uint8_t hw_multiplicity  # at least one has fpga_energy > 0
    uint8_t prescaled  # in addition to the multiplicity_below condition the current event is ready to prescale to it's timestamp

    uint64_t is_flagged

  ctypedef union CTFlags:
    uint8_t multiplicity  # if number of threshold triggers > 0

    uint64_t is_flagged

  ctypedef struct FSPProcessorFlags:
    HWMFlags hwm
    WPSFlags wps
    CTFlags ct
    EventFlags evt

  ### Observables
  ctypedef struct wps_obs:
    float sum_value  # what is the maximum PE within the integration windows
    int sum_offset  # when is the total sum offset reached?
    int sum_multiplicity  # How many channels did have a peak above thresholds
    float max_single_peak_value  # which one was the largest individual peak
    int max_single_peak_offset  # which sample contains this peak

  ctypedef struct hwm_obs:
    int hw_multiplicity  # how many channels have fpga_energy > 0
    unsigned short max_value  # what is the largest fpga_energy of those
    unsigned short min_value  # what is the smallest fpga_energy of those
    int sw_multiplicity # how many channels were above the fpga_energy threshold in software trigger and the required multiplicity

  ctypedef struct ct_obs:
    int multiplicity  # how many channels were above the threshold
    int trace_idx[FCIOMaxChannels]  # the corresponding fcio trace index
    unsigned short max[FCIOMaxChannels]  # the maximum per channel

  ctypedef struct evt_obs:
    int nconsecutive # if we found re-triggers how many events are consecutive from then on. the event with the extension flag carries the total number

  ctypedef struct prescale_obs:
    int n_hwm_prescaled # how many hwm channels were prescaled
    unsigned short hwm_prescaled_trace_idx[FCIOMaxChannels] # which channels were prescaled

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
    prescale_obs ps
    SubEventList sub_event_list

  ### Tie everything together in the state struct
  ctypedef struct FSPState:
    # ommits FSP internal fields here, see "fsp_state.h" for the full definition
    FSPWriteFlags write_flags
    FSPProcessorFlags proc_flags
    FSPObservables obs

  ### FSPConfig / FSPStatus
  ctypedef struct Timestamp:
    long seconds
    long nanoseconds

  ctypedef struct FSPTriggerConfig:
    int hwm_min_multiplicity
    int hwm_prescale_ratio[FCIOMaxChannels]
    int wps_prescale_ratio

    float wps_coincident_sum_threshold
    float wps_sum_threshold
    float wps_prescale_rate
    float hwm_prescale_rate[FCIOMaxChannels]

    HWMFlags wps_ref_flags_hwm
    CTFlags wps_ref_flags_ct
    WPSFlags wps_ref_flags_wps
    int n_wps_ref_map_idx
    int wps_ref_map_idx[FCIOMaxChannels]

    FSPWriteFlags enabled_flags
    Timestamp pre_trigger_window
    Timestamp post_trigger_window

  ctypedef struct FSPTraceMap:
    int format
    int map[FCIOMaxChannels]
    int n_mapped
    int enabled[FCIOMaxChannels]
    int n_enabled
    char label[FCIOMaxChannels][8];

  ctypedef struct DSPWindowedPeakSum:
    FSPTraceMap tracemap
    float gains[FCIOMaxChannels]
    float thresholds[FCIOMaxChannels]
    float lowpass[FCIOMaxChannels]
    int shaping_widths[FCIOMaxChannels]
    int dsp_margin_front[FCIOMaxChannels]
    int dsp_margin_back[FCIOMaxChannels]
    int dsp_start_sample[FCIOMaxChannels]
    int dsp_stop_sample[FCIOMaxChannels]
    int dsp_max_margin_front
    int dsp_max_margin_back

    int apply_gain_scaling

    int sum_window_size
    int sum_window_start_sample
    int sum_window_stop_sample
    float sub_event_sum_threshold

  ctypedef struct DSPHardwareMultiplicity:
    FSPTraceMap tracemap
    unsigned short fpga_energy_threshold_adc[FCIOMaxChannels]

  ctypedef struct DSPChannelThreshold:
    FSPTraceMap tracemap
    unsigned short thresholds[FCIOMaxChannels]

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
    FSPBuffer *buffer

    FSPTriggerConfig triggerconfig
    DSPWindowedPeakSum dsp_wps
    DSPHardwareMultiplicity dsp_hwm
    DSPChannelThreshold dsp_ct
    FSPStats stats
    FSPState* fsp_state

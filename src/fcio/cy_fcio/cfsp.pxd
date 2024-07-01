from numpy cimport uint8_t, uint64_t

cdef extern from "fsp.h":
cdef extern from "fcio.h":

  ctypedef struct _stflags:
    uint8_t hwm_multiplicity  # the multiplicity threshold has been reached
    uint8_t hwm_prescaled  # the event was prescaled due to the HWM condition
    uint8_t wps_abs  # the absolute peak sum threshold was reached
    uint8_t wps_rel  # the relative peak sum threshold was reached and a coincidence to a reference event is fulfilled
    uint8_t wps_prescaled  # the event was prescaled due to the WPS condition
    uint8_t ct_multiplicity  # a channel was above the ChannelThreshold condition
  ctypedef union STFlags:
    _stflags flags
    uint64_t is_flagged


  ctypedef struct _evtflags:
    uint8_t is_retrigger  # the event is a retrigger event
    uint8_t is_extended  # the event triggered (a) retrigger event(s)
  ctypedef union EventFlags:
    _evtflags flags
    uint64_t is_flagged


  ctypedef struct _wpsflags:
    uint8_t abs_threshold  # absolute threshold was reached
    uint8_t rel_threshold  # relative threshold was reached
    uint8_t rel_reference  # the event is a WPS reference event
    uint8_t rel_pre_window  # the event is in the pre window of a reference event
    uint8_t rel_post_window  # the event is in the post window of a reference event
    uint8_t prescaled  # in addition to the multiplicity_below condition the current event is ready to prescale to it's timestamp
  ctypedef union WPSFlags:
    _wpsflags flags    
    uint64_t is_flagged

  ctypedef struct _hwmflags:
    uint8_t multiplicity_threshold  # the multiplicity threshold (number of channels) has been reached
    uint8_t multiplicity_below  # all non-zero channels have an hardware value below the set amplitude threshold
    uint8_t prescaled  # in addition to the multiplicity_below condition the current event is ready to prescale to it's timestamp
  ctypedef union HWMFlags:
    _hwmflags flags
    uint64_t is_flagged

  ctypedef struct _ctflags:
    uint8_t multiplicity  # if number of threshold triggers > 0
  ctypedef union CTFlags:
    _ctflags flags
    uint64_t is_flagged


  ctypedef struct FSPWriteFlags:
    EventFlags event
    STFlags trigger
    int write

  ctypedef struct FSPProcessorFlags:
    HWMFlags hwm
    WPSFlags wps
    CTFlags ct

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
    const char* label[FCIOMaxChannels]  # the name of the channel given during setup
  ctypedef struct event_obs:
    int nextension  # if we found re-triggers how many events are consecutive from then on. the event with the extension flag carries the total number
  ctypedef struct SubEventList:
    int size
    int start[FCIOMaxSamples]
    int stop[FCIOMaxSamples] # first sample after trigger up is gone
    float wps_max[FCIOMaxSamples]
  ctypedef struct FSPObervables:
    wps_obs wps
    hwm_obs hwm
    ct_obs ct
    event_obs evt
    SubEventList sub_event_list

  ctypedef struct FSPState:
    # ommits FSP internal fields here, see "fsp_state.h" for the full definition
    FSPWriteFlags write_flags
    FSPProcessorFlags proc_flags
    FSPObservables obs


  FCIOGetFSPEvent(FCIOData* input, FSPState* fsp_state)


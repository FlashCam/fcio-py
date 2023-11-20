cdef extern from "fcio.h":

    # defines in fcio.h
    cdef const int FCIOMaxChannels
    cdef const int FCIOMaxSamples
    cdef const int FCIOMaxPulses
    cdef const int FCIOTraceBufferLength

    int FCIODebug(int level)

    ctypedef struct fcio_config:
        int telid
        int adcs
        int triggers
        int eventsamples
        int adcbits
        int sumlength
        int blprecision
        int mastercards
        int triggercards
        int adccards
        int gps
        unsigned int tracemap[FCIOMaxChannels]

    ctypedef struct fcio_event:
        int type
        float pulser
        int timeoffset[10]
        int deadregion[10]
        int timestamp[10]
        int timeoffset_size
        int timestamp_size
        int deadregion_size
        int num_traces
        unsigned short trace_list[FCIOMaxChannels]
        unsigned short* trace[FCIOMaxChannels]
        unsigned short* theader[FCIOMaxChannels]
        unsigned short traces[FCIOTraceBufferLength]

    ctypedef struct fcio_recevent:
        int type
        float pulser
        int timeoffset[10]
        int deadregion[10]
        int timestamp[10]
        int timeoffset_size
        int timestamp_size
        int deadregion_size
        int totalpulses
        int channel_pulses[FCIOMaxChannels]
        int flags[FCIOMaxPulses]
        float times[FCIOMaxPulses]
        float amplitudes[FCIOMaxPulses]

    ctypedef struct card_status:
        unsigned int reqid
        unsigned int status
        unsigned int eventno
        unsigned int pps
        unsigned int ticks
        unsigned int maxticks
        unsigned int numenv
        unsigned int numctilinks
        unsigned int numlinks
        unsigned int dummy
        unsigned int totalerrors
        unsigned int enverrors
        unsigned int ctierrors
        unsigned int linkerrors
        unsigned int othererrors[5]
        int environment[16]
        unsigned int ctilinks[4]
        unsigned int linkstates[256]

    ctypedef struct fcio_status:
        int status
        int statustime[10]
        int cards
        int size
        card_status data[256]

    ctypedef struct FCIOData:
        void* ptmio
        int magic
        fcio_config config
        fcio_event event
        fcio_status status
        fcio_recevent recevent

    ctypedef enum FCIOTag:
        FCIOConfig
        FCIOCalib
        FCIOEvent
        FCIOStatus
        FCIORecEvent
        FCIOSparseEvent

    ctypedef void* FCIOStream

    FCIOData* FCIOOpen(const char* name, int timeout, int buffer)

    int FCIOClose(FCIOData* x)

    int FCIOPutConfig(FCIOStream output, FCIOData* input)

    int FCIOPutStatus(FCIOStream output, FCIOData* input)

    int FCIOPutEvent(FCIOStream output, FCIOData* input)

    int FCIOPutSparseEvent(FCIOStream output, FCIOData* input)

    int FCIOPutRecEvent(FCIOStream output, FCIOData* input)

    int FCIOPutRecord(FCIOStream output, FCIOData* input, int tag)

    int FCIOGetRecord(FCIOData* x)

    FCIOStream FCIOConnect(const char* name, int direction, int timeout, int buffer)

    int FCIODisconnect(FCIOStream x)

    int FCIOTimeout(FCIOStream x, int timeout_ms)

    int FCIOWriteMessage(FCIOStream x, int tag)

    int FCIOWrite(FCIOStream x, int size, void* data)

    int FCIOFlush(FCIOStream x)

    int FCIOReadMessage(FCIOStream x)

    int FCIORead(FCIOStream x, int size, void* data)

    int FCIOWaitMessage(FCIOStream x, int tmo)

    ctypedef struct FCIOState:
        fcio_config* config
        fcio_event* event
        fcio_status* status
        fcio_recevent* recevent
        int last_tag

    ctypedef struct FCIOStateReader:
        FCIOStream stream
        int nrecords
        int max_states
        int cur_state
        FCIOState* states
        unsigned int selected_tags
        int timeout
        int nconfigs
        int nevents
        int nstatuses
        int nrecevents
        int cur_config
        int cur_event
        int cur_status
        int cur_recevent
        fcio_config* configs
        fcio_event* events
        fcio_status* statuses
        fcio_recevent* recevents

    FCIOStateReader* FCIOCreateStateReader(const char* peer, int io_timeout, int io_buffer_size, unsigned int state_buffer_depth)

    int FCIODestroyStateReader(FCIOStateReader* reader)

    int FCIOSelectStateTag(FCIOStateReader* reader, int tag)

    int FCIODeselectStateTag(FCIOStateReader* reader, int tag)

    FCIOState* FCIOGetState(FCIOStateReader* reader, int offset, int* timedout)

    FCIOState* FCIOGetNextState(FCIOStateReader* reader, int* timedout)

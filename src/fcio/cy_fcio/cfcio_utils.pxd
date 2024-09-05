cdef extern from "fcio_utils.h":

  int FCIOSetMemField(FCIOStream stream, void *mem_addr, size_t mem_size);

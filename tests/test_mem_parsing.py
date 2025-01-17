#!/usr/bin/env python3

import sys, os
import numpy as np
import fcio

import binascii

def add_to_buffer(buffer, bytes, offset, size):
  if isinstance(bytes, int):
    buffer[offset:offset + size] = bytearray(bytes.to_bytes(size, 'little',signed=True))
  elif isinstance(bytes, str):
    buffer[offset:offset + size] = bytearray(bytes.encode('utf-8'))
  else:
    buffer[offset:offset + size] = bytes
  return offset + size

if __name__ == "__main__":

  buffer = np.zeros(8192, dtype='byte')

  ## FCIO Protocol Header
  tmio_tag = -1000000001
  protocol = "FlashCamV1"
  offset = 0
  offset = add_to_buffer(buffer, -1000000001, offset, 4)
  offset = add_to_buffer(buffer, protocol, offset, len(protocol))
  offset = add_to_buffer(buffer, 0, offset, 64 - len(protocol))

  ## FCIOConfig Tag and some random data
  offset = add_to_buffer(buffer, -1, offset, 4)
  offset = add_to_buffer(buffer, 4, offset, 4)
  offset = add_to_buffer(buffer, 181, offset, 4)
  offset = add_to_buffer(buffer, 4, offset, 4)
  offset = add_to_buffer(buffer, 0, offset, 4)
  offset = add_to_buffer(buffer, 4, offset, 4)
  offset = add_to_buffer(buffer, 8192, offset, 4)

  x = fcio.FCIO()
  x.open(buffer, debug=5)

  ## FCIOEvent Tag and some random data
  newbuffer = np.zeros(8192, dtype='byte')
  offset = 0
  offset = add_to_buffer(newbuffer, -fcio.Tags.Event, offset,  4)
  offset = add_to_buffer(newbuffer, 4,  offset, 4)
  offset = add_to_buffer(newbuffer, 1,  offset, 4)
  offset = add_to_buffer(newbuffer, 4,  offset, 4)
  offset = add_to_buffer(newbuffer, 0,  offset, 4)

  x.set_mem_field(newbuffer)
  x.get_record()

  assert(fcio.Tags.Event == x.tag)

  offset = 0
  offset = add_to_buffer(newbuffer, -fcio.Tags.RecEvent, offset,  4)
  offset = add_to_buffer(newbuffer, 4,  offset, 4)
  offset = add_to_buffer(newbuffer, 1,  offset, 4)
  offset = add_to_buffer(newbuffer, 4,  offset, 4)
  offset = add_to_buffer(newbuffer, 0,  offset, 4)

  x.set_mem_field(newbuffer)
  x.get_record()
  assert(fcio.Tags.RecEvent == x.tag)

  offset = 0
  offset = add_to_buffer(newbuffer, -fcio.Tags.EventHeader, offset,  4)
  offset = add_to_buffer(newbuffer, 4,  offset, 4)
  offset = add_to_buffer(newbuffer, 1,  offset, 4)
  offset = add_to_buffer(newbuffer, 4,  offset, 4)
  offset = add_to_buffer(newbuffer, 0,  offset, 4)

  x.set_mem_field(newbuffer)
  x.get_record()
  assert(fcio.Tags.EventHeader == x.tag)

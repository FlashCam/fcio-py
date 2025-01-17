#!/usr/bin/env python3

import sys
from fcio import fcio_open, __version__

def print_eventno(filename):
  with fcio_open(filename) as io:
    for event in io.events:
      print(event.eventnumber, event.fpga_time_ns - event.start_time_ns[0] , event.dead_time_ns[0], event.cur_dead_time_ns[0])#, event.utc_unix_ns)
      # pass

if __name__ == "__main__":
  filename = sys.argv[1]
  print_eventno(filename)
  print(f"version: {__version__}")

#!/usr/bin/env python3

import sys
from fcio import fcio_open, __version__

def print_eventno(filename):
  with fcio_open(filename) as io:
    for event in io.events:
      for (trace_idx, run_time, dead_interval, dead_time, life_time) in zip(event.trace_list, event.run_time_nsec, event.dead_interval_nsec, event.dead_time_nsec, event.life_time_nsec):
        print(f"evtno {event.eventnumber} tidx {trace_idx:02d} ux_t {event.unix_time_utc_nsec} fpga_t {event.fpga_time_nsec} run_t {run_time} di_t {dead_interval} dt {dead_time} lt {life_time}")
      # pass

if __name__ == "__main__":
  filename = sys.argv[1]
  print_eventno(filename)
  print(f"version: {__version__}")

#!/usr/bin/env python3

import sys
from fcio import fcio_open, __version__, Tags

def true_write_flags(flags):
  present_flags = []
  for flag_type in ['event', 'trigger']:
    for name, flag in flags[flag_type].items():
      if name == 'is_flagged':
        continue
      if flag == 1:
        present_flags.append(name)
  return " ".join(present_flags)

def true_proc_flags(flags):
  present_flags = []
  for flag_type in ['hwm', 'ct', 'wps']:
    for name, flag in flags[flag_type].items():
      if name == 'is_flagged':
        continue
      if flag == 1:
        present_flags.append(name)
  return " ".join(present_flags)

def print_eventno(filename):
  with fcio_open(filename) as io:
    for event in io.events:
      # print(f"{event.eventnumber} {event.fpga_time_ns} {io.fsp.event.obs['wps']['max_value']:.2f} {io.fsp.event.obs['wps']['max_multiplicity']}")
      print(f"{event.eventnumber} {event.fpga_time_nsec} {io.fsp.event.obs['wps']['max_value']:.2f} {io.fsp.event.obs['wps']['max_multiplicity']} {true_write_flags(io.fsp.event.write_flags)} {true_proc_flags(io.fsp.event.proc_flags)}")


if __name__ == "__main__":
  filename = sys.argv[1]
  print_eventno(filename)
  print(f"version: {__version__}")

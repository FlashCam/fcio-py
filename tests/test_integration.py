#!/usr/bin/env python3

from memory_profiler import profile

import sys

from fcio import fcio_open, FCIOTag, __version__

def print_event(event, tag):
  if tag == FCIOTag.Event:
    card = "all"
  elif tag == FCIOTag.SparseEvent:
    card = [hex(_) for _ in event.card_address][0]

  print(f"card {card} event {event.eventnumber:3d} ch {event.timestamp[4]:3d} unix_time {event.utc_unix_ns:19d}  start_time {event.start_time_ns[0]:12d} daq_time {event.fpga_time_ns:12d} run_time {event.fpga_time_ns - event.start_time_ns[0]:12d} cur_dead_time {event.cur_dead_time_ns[0]:12d}  dead_time {event.dead_time_ns[0]:12d} live_time {(event.fpga_time_ns - event.dead_time_ns - event.start_time_ns)[0]:12d} dead fraction {event.dead_time_ns[0]/event.fpga_time_ns * 100:.3f}%")

def print_config(config):
  print(f"library version {__version__} adcs {config.adcs} samples {config.eventsamples}")

@profile
def parse_fcio(filename):
  with fcio_open(filename) as io:
    print_config(io.config)
    for ntags, tag in enumerate(io.tags):
      if tag == FCIOTag.Config:
        print_config(io.config)
      elif tag == FCIOTag.Event or tag == FCIOTag.SparseEvent:
        print_event(io.event, tag)
      elif tag == FCIOTag.RecEvent:
        print(f"recevent  {io.recevent.eventnumber} npulses {io.recevent.totalpulses} pulse_sum {io.recevent.amplitudes.sum()}")
        for ch, flags, times, amplitudes in io.recevent.pulses:
          print(f" channel {ch} flags {flags} times {times} amplitudes {amplitudes}")

# @profile
def parse_events(filename):
  with fcio_open(filename) as io:
    for event in io.events:
      print(event.eventnumber)


if __name__ == "__main__":
  filename = sys.argv[1]
  parse_fcio(filename)
  # parse_events(filename)

#!/usr/bin/env python3

from memory_profiler import profile

import sys

from fcio import fcio_open, Tags, __version__

def print_event(event, tag):
  if tag == Tags.Event:
    card = "all"
  elif tag == Tags.SparseEvent:
    card = [hex(_) for _ in event.card_address][0]

  print(f"card {card} event {event.eventnumber:3d} ch {event.timestamp[4]:3d} unix_time {event.unix_time_utc_nsec:19d} fpga_time {event.fpga_time_nsec:12d} run_time {event.run_time_nsec[0]:12d} dead_interval {event.dead_interval_nsec[0]:12d}  dead_time {event.dead_time_nsec[0]:12d} live_time {(event.life_time_nsec)[0]:12d} dead fraction {100.0 * event.dead_time_sec[0]/event.run_time_sec[0] :.1f}%")

def print_config(config):
  print(f"library version {__version__} adcs {config.adcs} samples {config.eventsamples}")

@profile
def parse_fcio(filename):
  with fcio_open(filename) as io:
    print_config(io.config)
    for ntags, tag in enumerate(io.tags):
      if tag == Tags.Config:
        print_config(io.config)
      elif tag == Tags.Event or tag == Tags.SparseEvent:
        print_event(io.event, tag)
      elif tag == Tags.RecEvent:
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

import sys

from fcio import fcio_open

def print_card_status(card_name, card_status):
  s = card_status
  print(f"{card_name} reqid {s.reqid} status {s.status} evtno {s.eventno} pps {s.pps} ticks {s.ticks} maxticks {s.maxticks}")

def print_status():
  filename = sys.argv[1]
  with fcio_open(filename) as io:
    for s in io.statuses:
      print(f"Status: {s.status} master {s.statustime_master_sec} server {s.statustime_server_sec} start time {s.statustime_master_sec} ncards {s.cards}")
      
      for card_status in s.master_card_status:
        print_card_status(".master", card_status)
      for card_status in s.trigger_card_status:
        print_card_status("..trigger", card_status)
      for card_status in s.adc_card_status:
        print_card_status("...adc", card_status)


def print_event():
  filename = sys.argv[1]
  with fcio_open(filename) as io:
    for e in io.events:
      print(e.type, e.eventnumber, e.runtime_sec, e.eventtime_ns, e.eventtime_sec, e.deadtime)
      
def print_stream():
  filename = sys.argv[1]
  with fcio_open(filename) as io:
    for tag in io.records:
      print(tag)

def plot_events():
  import matplotlib.pyplot as plt

  if len(sys.argv) < 2:
    print("fcio-plot-events <filename> <start,stop>")
    print("  optional: <start,stop> : either only number of events or first event and number of events.")
    sys.exit(1)

  elif (len(sys.argv) == 3):
    start_event = 0
    nevents = int(sys.argv[2])

  elif (len(sys.argv) == 4):
    start_event = int(sys.argv[2])
    nevents = int(sys.argv[3])
  else:
    start_event = 0
    nevents = -1

  filename = sys.argv[1]

  with fcio_open(filename) as io:
    for i, e in enumerate(io.events):
      if i < start_event:
        continue
      plt.plot(e.traces.T - e.baseline)

      if i == (start_event + nevents - 1):
        print(f"Read {i - start_event} events.")
        break
  plt.show()


def plot_peak_histogram():
  import matplotlib.pyplot as plt
  import numpy as np

  if len(sys.argv) < 2:
    print("fcio-plot-energy-histogram <filename> <start,stop>")
    print("  uses the daqenergy / integrator value, with it's caveats.")
    print("  optional: <start,stop> : either only number of events or first event and number of events.")
    sys.exit(1)

  if (len(sys.argv) == 3):
    start_event = 0
    nevents = int(sys.argv[2])

  elif (len(sys.argv) == 4):
    start_event = int(sys.argv[2])
    nevents = int(sys.argv[3])
  else:
    start_event = 0
    nevents = -1

  filename = sys.argv[1]

  with fcio_open(filename) as io:
    amplitudes = []
    for i, e in enumerate(io.events):
      if i < start_event:
        continue
      amplitudes.append(np.max(e.traces, axis=1) - e.baseline)
      if i == (start_event + nevents - 1):
        print(f"Read {i - start_event} events.")
        break

  amplitudes = np.array(amplitudes).T
  for ch in amplitudes:
    hist, edges = np.histogram(ch, bins=1000)
    bincentres = [(edges[i]+edges[i+1])/2. for i in range(len(edges)-1)]
    plt.step(bincentres, hist, where='mid', linestyle='-')

  plt.show()

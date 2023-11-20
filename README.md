# Installation

Run `python3 -m pip install fcio` to install from the pypi repository.

Build requirements are `Cython`, `numpy` and `meson-python` (all installed automatically by `pip`).

Clone this repo with `git clone https://github.com/FlashCam/fcio-python.git`.

## Makefile

Local usage and development is facilitated with a thin Makefile, wrapping `python3 -m build` and `python3 -m install` commands.

Run `make dev` to install with pip3 as local development installation, otherwise run `make build` and `make install` to build a wheel and install it.

# Description

`fcio-python` provides a read-only wrapper around the `fcio.c` io library used in `fc250b` based digitizer systems.

TODO: some text here

## Example

The following example opens an fcio file and prints some basic event content to stdout:

```python
from fcio import fcio_open

filename = 'path/to/an/fcio/file'

with fcio_open(filename, extended=True) as io:
  print("#evtno run_time utc_unix_sec utc_unix_nsec ntraces bl_mean bl_std")
  for event in io.events:
    print(f"{event.eventnumber} {event.run_time:.09f} {event.utc_unix_sec} {event.utc_unix_nsec} {event.trace_list.size} {event.fpga_baseline.mean():.1f} {event.fpga_baseline.std():.2f}")

```

The library provides scripts as examples, located in `src/fcio/cmds/cmds.py`.
Most useful as a quick entry is the script `fcio-plot-events` which plots the raw traces using matplotlib.


# Contributing

This project is licensed under the Mozilla Public License 2.0, see [LICENSE](LICENSE) for the full terms of use. The MPL
2.0 is a free-software license and we encourage you to feed back any improvements by submitting patches to the upstream
maintainers (see Contact below).

# Development

Development is best done in a local environment, e.g. using `venv`:

```
# create local environment, e.g.:
export MY_ENV=fcio
python3 -m venv $MY_ENV

# activate the environment
source $MY_ENV/bin/activate

# install the library in editable mode
python3 -m pip install -e .
# or using make
make dev
```
# Installation

Run `python3 -m pip install fcio` to install from the pypi repository.

# Description

`fcio-py` provides a read-only wrapper around the `fcio.c` io library used in `fc250b` based digitizer systems.

The wrapper exposes the `fcio.c` memory fields as closely as possible to standard c-structs using numpy ndarrays or scalars where applicable.
For convenience all supported fcio records are exposed as iterable properties of the base `FCIO` class to preselect records of interest.

# Usage



## Simple code example

The following example opens an fcio file and prints some basic event content to stdout:

```python
from fcio import fcio_open

filename = 'path/to/an/fcio/file'

with fcio_open(filename, extended=True) as io:
  print("#evtno run_time utc_unix_sec utc_unix_nsec ntraces bl_mean bl_std")
  for event in io.events:
    print(f"{event.eventnumber} {event.run_time:.09f} {event.utc_unix_sec} {event.utc_unix_nsec} {event.trace_list.size} {event.fpga_baseline.mean():.1f} {event.fpga_baseline.std():.2f}")

```

## Differences to C usage

- `fcio-py` codifies the assumption that a `FCIOConfig` record must be available and skips all previous records on opening
- reading of zstd or gzip compressed files is possible using suprocesses. This requires `zstd` or `gzip` to be available. If a file ends in `.zst` or `.gz` respectively and the `compression` parameter is default, this will happen automatically.

# Development

Development is best done in a local environment, e.g. using `venv`:

```
# create local environment:
export MY_ENV=fcio_dev
python3 -m venv $MY_ENV

# activate the environment
source $MY_ENV/bin/activate
```

This library depends on `meson-python/meson` as build tool and `Cython`/`numpy` to wrap the `c`-sources. These should be installed automatically wenn running `python3 -m build`.
To allow a more traditional workflow a thin `Makefile` is available which wraps the `python3` and `meson` specific commands.


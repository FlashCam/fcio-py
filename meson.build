
project('fcio',
  'c', 'cython',
  version : run_command(['tools/version_util.py'], check: true).stdout().strip(),
  license: 'MPL-2.0',
  meson_version : '>= 1.1.0',
  default_options : [
    'warning_level=3',
    'buildtype=release',
    'c_std=c99',
  ]
)

py_mod = import('python')
py3 = py_mod.find_installation(pure: false)
py_dep = py3.dependency()

incdir_numpy = run_command(py3,
  ['-c', 'import numpy; print(numpy.get_include())'],
  check : true
).stdout().strip()

bufio_proj = subproject('bufio')
bufio_inc = bufio_proj.get_variable('bufio_inc')
bufio_sources = bufio_proj.get_variable('bufio_sources')

tmio_proj = subproject('tmio')
tmio_inc = tmio_proj.get_variable('tmio_inc')
tmio_sources = tmio_proj.get_variable('tmio_sources')

fcio_proj = subproject('fcio')
fcio_inc = fcio_proj.get_variable('fcio_inc')
fcio_sources = fcio_proj.get_variable('fcio_sources')

py3.extension_module(
  'cy_fcio',
  'src/fcio/cy_fcio/cy_fcio.pyx',
  bufio_sources,
  tmio_sources,
  fcio_sources,
  install: true,
  include_directories: [
    bufio_inc,
    tmio_inc,
    fcio_inc,
    incdir_numpy
  ],
  subdir: 'fcio'
)

py3.install_sources(
    'src/fcio/__init__.py',
    subdir: 'fcio',
)

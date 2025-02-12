project(
  'fcio',
  'c',
  'cython',
  version: run_command([find_program('python').full_path(), 'tools/version_util.py'], check: true).stdout().strip(),
  license: 'MPL-2.0',
  meson_version: '>= 1.1.0',
  default_options: [
    'warning_level=2',
    'buildtype=release',
    'c_std=c11',
  ],
)

py3 = import('python').find_installation(pure: false)

incdir_numpy = run_command(py3, ['-c', 'import numpy; print(numpy.get_include())'], check: true).stdout().strip()

fcio_proj = subproject('fcio')
fcio_inc = fcio_proj.get_variable('fcio_inc')
fcio_sources = fcio_proj.get_variable('fcio_sources')
fcio_utils_sources = fcio_proj.get_variable('fcio_utils_sources')

tmio_proj = subproject('tmio')
tmio_inc = tmio_proj.get_variable('tmio_inc')
tmio_sources = tmio_proj.get_variable('tmio_sources')

bufio_proj = subproject('bufio')
bufio_inc = bufio_proj.get_variable('bufio_inc')
bufio_sources = bufio_proj.get_variable('bufio_sources')

fsp_proj = subproject('libfsp')
fsp_inc = fsp_proj.get_variable('fsp_inc')
fsp_sources = fsp_proj.get_variable('fsp_sources')

py3.extension_module(
  'fcio',
  'src/fcio/fcio.pyx',
  bufio_sources,
  tmio_sources,
  fcio_sources,
  fcio_utils_sources,
  fsp_sources,
  install: true,
  include_directories: [bufio_inc, tmio_inc, fcio_inc, fsp_inc, incdir_numpy],
  subdir: 'fcio',
)

py3.install_sources(
  'src/fcio/__init__.py',
  subdir: 'fcio',
)

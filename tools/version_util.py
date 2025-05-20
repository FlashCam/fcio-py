#!/usr/bin/env python3

try:
  from git import Repo
  GIT_INSTALL_FOUND = True
except ImportError:
  GIT_INSTALL_FOUND = False

def get_git_version(cwd):
  """ Try to get the current version from git tags. """
  try:
    repo = Repo(cwd)
    git_describe = repo.git.describe('--tags')
    parts = git_describe.split('-')
    if len(parts) == 1:
      return parts[0]
    elif len(parts) == 3:
      return f"{parts[0].removeprefix('v')}.dev{parts[1]}"
    else:
      return None
  except Exception:
    return None

def get_version_from_pkg_info(filename):
  """ Try to get the current version from a PKG-INFO file. """
  # Could probably do this with module `pkginfo` or similar, but this seems to work, too.
  try:
    with open(filename, 'r', encoding='utf-8') as fio:
      for line in fio:
        tokens = line.split()
        if tokens[0] == "Version:":
          return tokens[1]
      return None
  except FileNotFoundError:
    return None

if __name__ == "__main__":
  PKG_INFO_FILE = 'PKG-INFO'

  version = get_version_from_pkg_info(PKG_INFO_FILE)
  if not version and GIT_INSTALL_FOUND:
    version = get_git_version('.')

  if version:
    print(version)
  else:
    print("unknown")

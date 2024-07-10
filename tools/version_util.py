#!/usr/bin/env python3

from git import Repo
   
def get_git_version(cwd):
    try:
        repo = Repo(cwd)
        return repo.git.describe('--tags')
    except Exception:
        return None
 
def get_version_from_pkg_info(filename):
    # Could probably do this with `pkginfo` or something, but this seems to work, too.
    with open(filename, 'r') as fio:
        for line in fio:
            parts = line.split()
            if parts[0] == "Version:":
                return parts[1]

if __name__ == "__main__":
    version_file_path = 'PKG-INFO'

    git_describe = get_git_version('.')
    if git_describe:
        parts = git_describe.split('-')
        if len(parts) == 1:
            git_version = parts[0]
        elif len(parts) == 3:
            git_version = f"{parts[0]}.dev{parts[1]}"
        else:
            print("Unkown")
            # raise KeyError(f"Parsed git version does not conform the expected number of dashes. Got {git_describe}, but only none or 2 dash-separated format is expected from `git describe`.")
        print(git_version)
    else:
        file_version = get_version_from_pkg_info(version_file_path)
        if file_version:
            print(file_version)
        else:
            print("Unknown")

# Changelog

## [0.7.4] - 2025-03-12

- Add input checking to set_mem_field.
- Require numpy>=2 for compiling, but numpy>=1.23.5 as run time dependency.

## [0.7.3] - 2025-03-11

- Update CI pipeline to compile wheels.

## [0.7.2] - 2025-03-10

- Fix bug when accessing theader field in eventheaders.
- Update CI pipeline to pre-build wheels

## [0.7.0] - 2025-03-07

- Add support for FSPConfig,FSPEvent,FSPStatus records
- go back to `_nsec` suffix.
- add additional accessors

## [0.2.5] - 2024-04-26

### Added

- workflow updates, internal

## [0.2.4] - 2024-04-26

### Added

- FCIOLimit exposing compile-time limits of the fcio library.

### Changed

- Properties with unit nanoseconds have suffice `_ns` instead of `_nsec` now.
- Variable field size changes in records are now exposed via return of sliced numpy arrays
  instead of using stride tricks. Fixes a memory leak.

## [0.2.3] - 2023-12-01

### Added

- Added dead time calculation to CyEventExt.
- Added automatic deployment of the documentation to github pages.

## [0.2.2] - 2023-11-27

### Added

- Added publish workflow, pushing source distributions to pypi and test.pypi.

## [0.2.1] - 2023-11-27

### Added

- The project is tagged and moved to github.

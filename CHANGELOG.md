# Change Log

All notable changes to this project will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

## [unreleased] - unreleased

### Fixed

- Fix potential connection hang when timer event subscription fails ([PR #44](https://github.com/ponylang/livery/pull/44))

### Added


### Changed

- Require ponyc 0.63.1 or later ([PR #44](https://github.com/ponylang/livery/pull/44))

## [0.1.4] - 2026-04-07

### Fixed

- Fix connection stall after large message with backpressure ([PR #42](https://github.com/ponylang/livery/pull/42))

## [0.1.3] - 2026-03-28

### Fixed

- Fix crash when a WebSocket connection is disposed before initialization completes ([PR #39](https://github.com/ponylang/livery/pull/39))

## [0.1.2] - 2026-03-24

### Changed

- Update hobby dependency to 0.4.0 ([PR #36](https://github.com/ponylang/livery/pull/36))

## [0.1.1] - 2026-03-22

### Fixed

- Fix WebSocket connections hanging on shutdown when client disconnects ([PR #35](https://github.com/ponylang/livery/pull/35))
- Fix idle timeout firing prematurely on TLS WebSocket connections ([PR #35](https://github.com/ponylang/livery/pull/35))

## [0.1.0] - 2026-03-14

### Added

- Initial release


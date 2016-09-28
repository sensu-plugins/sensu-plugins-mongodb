#Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format listed at [Keep A Changelog](http://keepachangelog.com/)

## [Unreleased]
## [1.1.0] - 2016-09-22
## Added
- Inclusion of check-mongodb-metrics.rb to perform checks agains the same data metrics-mongodb.rb produces.
- Inclusion of lib/sensu-plugins-mongodb/metics.rb to share metric collection logic.
- Tests to the metrics processing shared code.
- Support for SSL certificates for clients.

## Changed
- Moved most of metrics-mongodb.rb code to shared library.
- MongoDB version checks to skip missing metrics.
- Renamed some metrics to become standard with MongoDB 3.2 equivalent
  (so checks/queries don't have to bother with version detection).

## [1.0.2] - 2016-08-11
## Added
- Inclusion of metrics-mongodb-replication.rb to produce replication metrics including lag statistics
- Updated metrics-mongodb.rb to include version checks to ensure execution in mongodb > 3.2.x

## [1.0.1] - 2016-07-13
### Added
- Additional metrics not included in original metrics-mongodb.rb

## [1.0.0] - 2016-06-03
### Removed
- support for Rubies 1.9.3 and 2.0

### Added
- support for Ruby 2.3

### Changed
- Update to rubocop 0.40 and cleanup
- Update to mongo gem 2.2.x and bson 4.x for MongoDB 3.2 support

### Fixed
- Long was added as a numeric type
- metrics-mongodb.rb: fix typo

## [0.0.8] - 2016-03-04
### Added
- Add a ruby wrapper script for check-mongodb.py

### Changed
- Rubocop upgrade and cleanup

## [0.0.7] - 2015-11-12
### Fixed
- Stopped trying to gather indexCounters data from mongo 3 (metrics-mongodb.rb)

### Changed
- Updated mongo gem to 1.12.3

## [0.0.6] - 2015-10-13
### Fixed
- Rename option to avoid naming conflict with class variable name
- Add message for replica set state 9 (rollback)
- Installation fix

## [0.0.5] - 2015-09-04
### Fixed
- Fixed non ssl mongo connections

## [0.0.4] - 2015-08-12
### Changed
- general gem cleanup
- bump rubocop

## [0.0.3] - 2015-07-14
### Changed
- updated sensu-plugin gem to 1.2.0

## [0.0.2] - 2015-06-03
### Fixed
- added binstubs

### Changed
- removed cruft from /lib

## 0.0.1 - 2015-05-20
### Added
- initial release

[Unreleased]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.0.0...HEAD
[1.0.0]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.8...1.0.0
[0.0.8]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.7...0.0.8
[0.0.7]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.6...0.0.7
[0.0.6]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.5...0.0.6
[0.0.5]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.4...0.0.5
[0.0.4]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.3...0.0.4
[0.0.3]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.2...0.0.3
[0.0.2]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.1...0.0.2

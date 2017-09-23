# Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

This CHANGELOG follows the format located [here](https://github.com/sensu-plugins/community/blob/master/HOW_WE_CHANGELOG.md)

## [Unreleased]

## [2.0.0] - 2017-09-23
### Breaking Change
- bumped requirement of `sensu-plugin` [to 2.0](https://github.com/sensu-plugins/sensu-plugin/blob/master/CHANGELOG.md#v200---2017-03-29) (@majormoses)

### Fixed
- check-mongodb-metric.rb: make `--metric` required since it is (@majormoses)

## [1.4.1] - 2017-09-23
### Fixed
- Support for database size metrics (@fandrews)

### Changed
- updated changelog guidelines location (@majormoses)

## [1.4.0] - 2017-09-05
### Added
- Support for returning replicaset state metrics (@naemono)
- Tests covering returning replicaset state metrics (@naemono)
- Ruby 2.4.1 testing

## [1.3.0] - 2017-05-22
### Added
- Support for database size metrics (@naemono)
- Tests covering returning database size metrics (@naemono)

## [1.2.2] - 2017-05-08
### Fixed
- `check-mongodb.py`: will now correctly crit on connection issues (@majormoses)
## [1.2.1] - 2017-05-07
### Fixed
- `check-mongodb.py`: fixed issue of param building with not/using ssl connections (@s-schweer)

## [1.2.0] - 2017-03-06
### Fixed
- `check-mongodb.py`: Set read preference for pymongo 2.2+ to fix 'General MongoDB Error: can't set attribute' (@boutetnico)
- `check-mongodb.py`: Fix mongo replication lag percent check showing password in plain text (@furbiesandbeans)
- `metrics-mongodb-replication.rb`: Sort replication members to ensure the primary is the first element (@gonzalo-radio)

### Changed
- Update `mongo` gem to 2.4.1, which adds support for MongoDB 3.4 (@eheydrick)

## [1.1.0] - 2016-10-17
### Added
- Inclusion of check-mongodb-metrics.rb to perform checks against the same data metrics-mongodb.rb produces. (@stefano-pogliani)
- Inclusion of lib/sensu-plugins-mongodb/metics.rb to share metric collection logic. (@stefano-pogliani)
- Tests to the metrics processing shared code.  (@stefano-pogliani)
- Support for SSL certificates for clients. (@b0d0nne11)
- Inclusion of metrics-mongodb-replication.rb to produce replication metrics including lag statistics (@stefano-pogliani)
- Updated metrics-mongodb.rb to include version checks to ensure execution in mongodb > 3.2.x (@RycroftSolutions)
- Additional metrics not included in original metrics-mongodb.rb (@RycroftSolutions)

### Changed
- Moved most of metrics-mongodb.rb code to shared library. (@stefano-pogliani)
- MongoDB version checks to skip missing metrics. (@stefano-pogliani)
- Renamed some metrics to become standard with MongoDB 3.2 equivalent
  (so checks/queries don't have to bother with version detection). (@stefano-pogliani)

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

[Unreleased]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/2.0.0...HEAD
[2.0.0]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.4.1...2.0.0
[1.4.1]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.4.0...1.4.1
[1.4.0]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.3.0...1.4.0
[1.3.0]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.2.1...1.3.0
[1.2.1]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.2.0...1.2.1
[1.2.0]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.8...1.0.0
[0.0.8]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.7...0.0.8
[0.0.7]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.6...0.0.7
[0.0.6]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.5...0.0.6
[0.0.5]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.4...0.0.5
[0.0.4]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.3...0.0.4
[0.0.3]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.2...0.0.3
[0.0.2]: https://github.com/sensu-plugins/sensu-plugins-mongodb/compare/0.0.1...0.0.2

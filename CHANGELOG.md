# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.5.0

### Added

- The default data directory in a Rails application can be set with the `config.support_table.data_directory` option in the Rails application configuration.
- Added rake task `support_table_data:add_yard_docs` for Rails applications that will add YARD documentation to support table models for the named instance helpers. There is also a task `support_table_data:verify_yard_docs` that can be used in a build pipeline to verify that the documentation is up to date.
- The data synchronization task is now automatically attached to several Rails tasks: `db:seed`, `db:seed:replant`, `db:prepare`, `db:test:prepare`, `db:fixtures:load`. Support tables will be synced after running any of these tasks. This can be disabled by setting `config.support_table.auto_sync = false` in the Rails application configuration.

### Changed

- The default data directory is now set in a Railtie and can be overridden with the `config.support_table.data_directory` option in the Rails application configuration.
- The `support_table_key_attribute` method now returns "id" if not explicitly set instead of implicitly interpreting `nil` as the primary key. This makes the behavior more consistent and explicit and avoids edge cases when running the code in environments where the database connection is not available. This is a breaking change if the table uses a primary key other than "id" and the `support_table_key_attribute` was not explicitly set to that primary key.

## 1.4.0

### Fixed

- Honor single table inheritance class when creating new records in the database. This fixes issues where validations and callbacks on subclasses could be skipped when creating new records.

### Removed

- Removed support for ActiveRecord versions prior to 6.1.

## 1.3.1

### Added

- Added support for autosave associations. Data in autosave associations will be persisted when the support table is synced if it was changed by the support table data.

## 1.3.0

### Added

- Added `support_table_dependency` method to explicitly define support table dependencies that cannot be inferred from model associations.

## 1.2.4

### Fixed

- Fixed issue with `sync_all!` finding obsolete classes that are no longer defined as support tables in development or test environments.

## 1.2.3

### Fixed

- Made loading data from the data files thread safe.

## 1.2.2

### Fixed

- Added thread safety to modification of internal class variables.

## 1.2.1

### Changed

- Ignore invalid associations when inspecting reflections on `sync_all!` to establish the load order. These kinds of errors have nothing to do with the support table definition and create confusion when the are raised while syncing data.

## 1.2.0

### Added

- Added `named_instance` method to load a named instance from the database.
- Added class method `named_instance_data` to return attributes from the data files for a named instance.
- Added handling for `has_many through` associations to load the dependent through associations first.

## 1.1.2

### Fixed

- Ignore anonymous ActiveRecord classes when calling `sync_all!`.

## 1.1.1

- Freeze values returned from helper methods.

## 1.1.0

### Added

- Helper methods can defined on the class to expose attributes for named instances without requiring a database connection.

## 1.0.0

### Added

- Add SupportTableData concern to enable automatic syncing of data on support tables.

# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

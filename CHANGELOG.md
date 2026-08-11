# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.7.0

### Fixed

- `sync_table_data!` now retries once on `ActiveRecord::RecordNotUnique` errors caused by a concurrent sync in another process inserting the same rows.
- `sync_table_data!` with `delete_missing: true` now raises an `ArgumentError` instead of deleting every row in the table when the data files contain no rows.
- `sync_table_data!` now raises an `ArgumentError` when a data file row has no value for the key attribute. Previously such rows were collapsed into a single record with a blank key.
- `sync_table_data!` now returns an empty array instead of `nil` when the table does not exist.
- Fixed broken cycle detection in the autosave association check during syncs that could cause infinite recursion on cyclic autosave associations.
- Syncing a single table inheritance subclass no longer inserts duplicate or wrongly typed rows for records defined in the base class' data files. Existing rows are matched without the inheritance type condition, and new rows default to the type of the class whose data file defines them.
- Single table inheritance subclasses now share the support table state defined on their base class regardless of load order. Previously class methods like `instance_names` and `protected_instance?` raised `NoMethodError` and named instance helpers could be missing on subclasses.
- `protected_instance?` and `instance_keys` now include data files added to single table inheritance subclasses and no longer return stale results when data files are added after their values were first computed.
- `sync_table_data!` with `delete_missing: true` no longer deletes rows that are managed by data files added to single table inheritance subclasses.
- Records are now merged in strict data file order, so later files take precedence even when named instance files are mixed with list format files.
- Data files that override attributes on a named instance are now merged by the instance name rather than only by the key attribute. Previously an override that did not repeat the key attribute value was treated as a new record and inserted as an extra row on every sync.
- Named instance helper methods and `named_instance_data` now return the merged values that are synced to the database. Previously the helpers permanently returned the values from the first file that defined the named instance.
- Entries under a name beginning with an underscore are treated as anonymous records even when the value is a single hash. Previously two files reusing the same underscore name each with a single hash were merged into one record, silently dropping rows.
- YAML data files can now use anchors/aliases and date/time values. Previously these raised `Psych::AliasesNotEnabled` or `Psych::DisallowedClass` errors.
- Generated predicate methods (e.g. `record.active?`) now cast the data file value to the attribute type before comparing, so they no longer silently return `false` when the types differ (always the case for CSV data files, where all values are strings).
- `named_instance` now raises an `ActiveRecord::RecordNotFound` error for undefined named instances instead of querying the database for a `nil` key.
- `named_instance_attribute_helpers` can now be called again with an attribute that was already registered without raising an `ArgumentError`.
- Modifications to memoized class-level state are now synchronized to avoid races on Ruby implementations without a global interpreter lock.
- Setting `config.support_table.auto_sync = false` before the gem is loaded is no longer overwritten back to `true` by the Railtie.
- Data file names containing extra dots no longer break the class name detection used by `SupportTableData.sync_all!` to eager load models.
- Error messages for invalid named instance definitions now include the model class name instead of repeating the instance name.
- The `:compact` YARD format now emits macros that YARD can actually expand. Previously the generated docs resolved to methods with no description, `@return`, or `@raise` tags and documented the predicate methods as class methods. Macro names are also namespaced per class so models do not overwrite each other's macros.
- The documentation tasks now remove duplicated generated YARD doc blocks (e.g. left over from a bad merge) instead of corrupting the model source file.
- The documentation tasks no longer report success when a model raises an `ArgumentError` for an invalid named instance definition.

## 1.6.1

### Fixed

- Fixed issue with YARD and RBS documentation tasks possibly raising an error if a named value method is deprecated and wrapped to return an error. Types are now inferred directly from the data rather than calling a method.

## 1.6.0

### Added

- Added `delete_missing` option to `sync_table_data!` and `sync_all!`. When set to `true`, any records in the database that are not defined in the data files will be deleted. This option defaults to `false` to preserve backward compatibility.
- Each model can now choose how its YARD docs are generated by setting `self.support_table_yard_docs` to `:full` (the default — verbose comment block per method), `:compact` (shared `@!macro` definitions plus a short `@!method`/`@!macro` pair per method, dramatically reducing comment-block size on tables with many named instances), or `:none` (skip generation entirely; previously generated docs are stripped on the next run). IDEs and `yard doc` resolve the compact form into the same per-method documentation as the verbose form.
- Attribute helper return types in the generated YARD and RBS docs are now inferred per method by inspecting the value the helper actually returns (`String`, `Integer`, `Boolean`, etc.) instead of the generic `Object`/`untyped`. Because the helpers return frozen literals from the parsed data file, the documentation tasks no longer require a database connection.
- Added opt-in RBS signature generation. The new tasks `support_table_data:rbs`, `support_table_data:rbs:verify`, and `support_table_data:rbs:remove` write/check/delete `sig/<model_path>.rbs` files so the named instance helpers are visible to Ruby LSP, Steep, RubyMine, and other RBS-aware tools without polluting the model source files. The output directory can be overridden with `SupportTableData.rbs_signatures_path`.

## 1.5.2

### Added

- Added `rubocop:disable all` around generated YARD documentation to prevent RuboCop offenses in the generated code. This ensures that the generated documentation does not cause any issues with RuboCop linting in the project.

## 1.5.1

### Added

- YARD documentation tasks can now take an optional file path argument to add, verify, or remove documentation for a specific support table model instead of all models. For example, you can run `bundle exec rake support_table_data:yard_docs:add[app/models/color.rb]` to add documentation for the `Color` model.
- Added comment in generated YARD documentation indicating the command to run to update them so that it's clear to users how to keep the documentation up to date.
- Aliased `support_table_data:yard_docs` to `support_table_data:yard_docs:add` for convenience since adding the documentation is the most common action.

## 1.5.0

### Added

- The default data directory in a Rails application can be set with the `config.support_table.data_directory` option in the Rails application configuration.
- Added rake task `support_table_data:yard_docs:add` for Rails applications that will add YARD documentation to support table models for the named instance helpers. There is also a task `support_table_data:yard_docs:verify` that can be used in a build pipeline to verify that the documentation is up to date. You can also remove the documentation with the `support_table_data:yard_docs:remove` task.
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

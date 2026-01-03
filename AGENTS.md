# Copilot Instructions for support_table_data

## Project Overview

A Ruby gem providing an ActiveRecord mixin for managing support/lookup tables with canonical data defined in YAML/JSON/CSV files. The gem dynamically generates helper methods to reference specific records naturally in code (e.g., `Status.pending` instead of `Status.find_by(name: 'Pending')`).

**Core concept**: Support tables blur the line between data and code—they contain small canonical datasets that must exist for the application to work.

## Architecture

### Key Components

- **`SupportTableData` module** ([lib/support_table_data.rb](lib/support_table_data.rb)): Main concern mixed into ActiveRecord models
- **Named instance system**: Dynamically generates class methods (`.pending`), predicate methods (`.pending?`), and attribute helpers (`.pending_id`) from hash-based data files
- **Data sync engine**: Compares canonical data files with database records, creating/updating as needed in atomic transactions
- **File parsers**: Supports YAML, JSON, and CSV formats with unified interface

### Data Flow

1. Data files (YAML/JSON/CSV) define canonical records with unique key attributes
2. `add_support_table_data` registers file paths and triggers method generation for hash-based files
3. `sync_table_data!` parses files, loads matching DB records, and updates/creates within transactions
4. Named instance methods are dynamically defined via `class_eval` with memoization

## Development Workflows

### Running Tests

```bash
bundle exec rspec                    # Run all specs
bundle exec rspec spec/support_table_data_spec.rb  # Single file
bundle exec rake appraisals          # Test against all ActiveRecord versions
```

Uses RSpec with in-memory SQLite database. Test models defined in [spec/models.rb](spec/models.rb), data files in `spec/data/`.

### Testing Against Multiple ActiveRecord Versions

The gem supports ActiveRecord 6.0-8.0. Uses Appraisal for multi-version testing:

```bash
bundle exec appraisal install        # Install all gemfiles
bundle exec appraisal rspec          # Run specs against all versions
```

See `Appraisals` file and `gemfiles/` directory.

### Code Style

Uses Standard Ruby formatter:

```bash
bundle exec rake standard:fix        # Auto-fix style issues
```

## Critical Patterns

### Named Instance Method Generation

**Hash-based data files** trigger dynamic method generation. Example from [spec/data/colors/named_colors.yml](spec/data/colors/named_colors.yml):

```yaml
red:
  id: 1
  name: Red
  value: 16711680
```

Generates:
- `Color.red` → finds record by id
- `color_instance.red?` → tests if `color_instance.id == 1`
- `Color.red_id` → returns `1` (if `named_instance_attribute_helpers :id` defined)

**Implementation**: See `define_support_table_named_instance_methods` in [lib/support_table_data.rb](lib/support_table_data.rb#L230-L265). Methods are generated using `class_eval` with string interpolation.

### Custom Setters for Associations

Support tables often reference other support tables via named instances. Pattern from [spec/models.rb](spec/models.rb#L72-L74):

```ruby
def group_name=(value)
  self.group = Group.named_instance(value)
end
```

Allows data files to reference related records by instance name instead of foreign keys.

### Key Attribute Configuration

By default, uses model's `primary_key`. Override for non-id keys:

```ruby
self.support_table_key_attribute = :name  # Use 'name' instead of 'id'
```

Key attributes cannot be updated—changing them creates new records.

### Dependency Resolution

`sync_all!` automatically resolves dependencies via `belongs_to` associations and loads tables in correct order. For complex cases (join tables, indirect dependencies), explicitly declare:

```ruby
support_table_dependency "OtherModel"
```

See [lib/support_table_data.rb](lib/support_table_data.rb#L219-L222) and dependency resolution logic.

## Testing Conventions

- **Test data isolation**: Each test deletes all records in `before` block ([spec/spec_helper.rb](spec/spec_helper.rb))
- **Sync before assertions**: Tests call `sync_table_data!` or `sync_all!` before verifying records exist
- **Multi-file merging**: Tests verify that multiple data files for same model merge correctly (see `Color` model with 5 data files)
- **STI handling**: See `Polygon`/`Triangle`/`Rectangle` tests for Single Table Inheritance patterns

## Common Pitfalls

1. **Method name conflicts**: Named instance methods raise `ArgumentError` if method already exists. Instance names must match `/\A[a-z][a-z0-9_]+\z/`
2. **Array vs hash data**: Only hash-keyed data generates named instance methods. Use arrays or underscore-prefixed keys (`_others`) for records without helpers
3. **Protected instances**: Records in data files cannot be deleted via `destroy` (though this gem doesn't enforce it—see companion caching gem)
4. **Transaction safety**: All sync operations wrapped in transactions; changes rollback on failure

## Rails Integration

In Rails apps, the gem automatically:
- Sets `SupportTableData.data_directory` to `Rails.root/db/support_tables`
- Provides `rake support_table_data:sync` task ([lib/tasks/support_table_data.rake](lib/tasks/support_table_data.rake))
- Handles eager loading in both classic and Zeitwerk autoloaders

## File References

- Main module: [lib/support_table_data.rb](lib/support_table_data.rb)
- Test models: [spec/models.rb](spec/models.rb) - comprehensive examples of patterns
- Sync task: [lib/tasks/support_table_data.rake](lib/tasks/support_table_data.rake)
- Architecture docs: [ARCHITECTURE.md](ARCHITECTURE.md) - detailed diagrams and design decisions

## Version Compatibility

- Ruby ≥ 2.5
- ActiveRecord ≥ 6.0
- Ruby 3.4+: Requires `csv` gem in Gemfile (removed from stdlib)

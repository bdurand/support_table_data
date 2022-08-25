# Support Table Data

[![Continuous Integration](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

This gem provides an mixin for ActiveRecord models for support tables that allow you load data from YAML, JSON, or CSV files. It is intended to solve issues with support tables (also known as lookup tables) that contain a small set of canonical data that must exist for your application to work.

These kinds of models blur the line between data and code. You'll often end up with constants and application logic based on specific values from the table. By using this gem, you can easily define methods for loading and comparing specific instances. This can really help clean up your code, make it read far more naturally, and prevent you from having to define dozens of constants or reference magic values.

## Usage

For the examples below, we'll suppose we have a simple `Status` model where each row has an id, unique name, and emoji icon and where we only have a handful of statuses: "Pending", "In Progress", "Completed".

```ruby
class Thing < ApplicationRecord
  belongs_to :status
end
```

Now we may have code that needs to reference the status and make decisions based on it. This means that every environment must always have the exact same values in it. You can solve for that in with the gem by defining the data in a YAML file:

```yaml
- id: 1
  name: Pending
  icon: :clock:

- id: 2
  name: In Progress
  icon: :construction:

- id: 3
  name: Completed
  icon: :heavy_check_mark:
```

You can then use this mixin to match that data with your model:

```ruby
class Status < ApplicationRecord
  include SupportTableData

  # Set the default location for data files (this is the default in a Rails application)
  self.support_table_data_directory = Rails.root + "db" + "support_tables"

  # Add a data file; you can also specify an absolute path. You can add multiple data files.
  add_support_table_data "statuses.yml"
end
```

### Specifying Data Files

You use the `add_support_table_data` class method to add a data file path. This file must be either a YAML, JSON, or CSV file that defines a list of attributes. YAML and JSON files must be an array where each element is a hash of the attributes that should be set. CSV files must use comma delimiters, double quotes as the quote characters, and must have a header row with the attribute names.

There must be an attribute that uniquely identifies in each element that will never change. By default, this will be the row id. You can change this with the `support_table_key_attribute` class attribute. This attribute is used to identify each row and match it with the data in the file. You cannot change a key attribute. If you do, a new record will be created with that key attribute an the existing row with the old will be left in the table. If you don't use the id as the key attribute, you don't need to include the ids in the data file.

You can specify data files as relative paths. If you do, they will be located from the value set in the class with the `support_table_data_directory` class attribute. If this value is not set, the global value set in `SupportTableData.data_directory` will be used. Otherwise, the path will be resolved relative to the current working directory. In a Rails application, the `SupportTableData.data_directory` will be automatically set to `db/support_tables/`. The directory to load relative files from must be set before loading your model classes.

### Loading Data

You can use the `sync_table_data!` class method to synchronize the data in your database table with the value in the data files. Generally you would want to call this from a database or seed migration any time you change any of the data files.

```ruby
Status.sync_table_data!
```

This will add any missing records to the table and update the attributes of any records that don't match the values in the data files. Records that do not appear in the data files will not be touched. Any attributes not specified in the data files will not be changed.

The number of rows coming from data files should be fairly small since they will all need to be loaded in to memory. It is possible to load just a handful of rows in a large table since only rows in the data files will be synced. You could use this feature if your table allows user entered values, but has a few rows that have to exist. Attributes not specified in the data files will also be left alone and not be synced.

You should also include a call to sync support tables in your environment bootstrap scripts (i.e. `bin/update` in a Rails application) or mechanism used to seed the database.

### Named Instances

You can also automatically defined helper methods to load and test instances. This allows you to add more natural ways of referencing specific records.

Named instances are defined if you supply a hash instead of an array in the data files. The hash keys must be valid Ruby method names. Keys that begin with and underscore will not be used to generate named instances. If you only want to create named instances on a few rows in a table, you can add them in an array under an underscored key.

Here is an example data file using named instances:

```yaml
pending:
  id: 1
  name: Pending
  icon: :clock:

in_progress:
  id: 2
  name: In Progress
  icon: :construction:

completed:
  id: 3
  name: Completed
  icon: :heavy_check_mark:

_others:
  - id: 4
    name: Draft

  - id: 5
    name: Deleted
```

The hash keys will be used to define helper methods to load and test records. In this example, our model would define these methods that can make it far more natural to reference specific instances.

```ruby
Status.pending      # Status.find_by!(id: 1)
Status.in_progress  # Status.find_by!(id: 2)
Status.completed    # Status.find_by!(id: 3)

status.pending?     # status.id == 1
status.in_progress? # status.id == 2
status.completed?   # status.id == 3
```

Helper methods will not override already defined methods on a model class. If a method is already defined, an `ArgumentError` will be raised.

### Caching

You can use the companion [support_table_cache gem](https://github.com/bdurand/support_table_cache) to add caching support to your models so that you don't need to constantly query the database for records that will never change. If you have a small table with a few dozen static rows, you should consider caching the values in memory.

```
class Status < ApplicationRecord
  include SupportTableData
  include SupportTableCache

  add_support_table_data "statuses.yml"

  # Cache lookups for finding by name or id.
  cache_by :name
  cache_by :id

  # Cache records in local memory instead of a shared cache.
  self.support_table_cache = :memory
end

class Thing < ApplicationRecord
  belongs_to :status

  # Use caching to load the association rather than hitting the database every time.
  cache_belongs_to :status
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem "support_table_data"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install support_table_data
```

## Contributing

Open a pull request on [GitHub](https://github.com/bdurand/support_table_data).

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

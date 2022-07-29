# Support Table Data

[![Continuous Integration](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

This gem provides an mixin for ActiveRecord models for small support tables that allow you load data from YAML or JSON files. It is intended to solve issues with support tables that contain a small set of canonical data that must exist for your application to work. These are the types of things that blur the line between data and code. You'll often end up with constants and application logic based on specific values from the table.

## Usage

For the examples below, we'll suppose we have a simple `Status` model where each row has an id, unique name, and emoji icon and where we only have a handful of statuses: "Pending", "In Progress", "Completed".

```ruby
class Thing < ApplicationRecord
  belongs_to :status
end
```

Now we may have code that needs to reference the status and make decisions based on it. This means that every environment must always have the exact same values in it. You can solve for that in with the gem by defining the data in a YAML file:

```yaml
1:
  name: Pending
  icon: :clock:

2:
  name: In Progress
  icon: :construction:

3:
  name: Completed
  icon: :heavy_check_mark:
```

You can then use this mixin to tell your model what data it should have in it and to use that data
to define helper methods:

```ruby
class Status < ApplicationRecord
  include SupportTableData

  # Set the default location for data files (this is the default in a Rails application)
  self.support_table_data_directory = Rails.root + "db" + "support_tables"

  # Add a data file; you can also specify an absolute path. You can add multiple data files.
  add_support_table_data "statuses.yml"

  # Define instance reader methods for each name value.
  define_instances_from :name

  # Define predicate methods for each name value.
  define_predicates_from :name
end
```

### Specifying Data Files

You use the `add_support_table_data` class method to add a data file path. This file must be either a YAML or JSON file that defines a Hash. The keys for the hash must be a value that uniquely identifies each row and which will never change. By default, this will be the row id. You can change this with the `support_table_key_attribute` class attribute.

Relative paths to data files will be located from the value set in the class with the `support_table_data_directory` class attribute. If this value is not set, the global value set in `SupportTableData.data_directory` will be used. Otherwise, the path will be resolved relative to the current working directory. In a Rails application, the `SupportTableData.data_directory` will be automatically set to `db/support_tables/`. Note that the search directories must be set before loading your model classes.

### Loading Data

You can use the `sync_table_data!` class method to synchronize the data in your database table with the value in the data files. Generally you would want to call this from a database or seed migration any time you change any of the data files.

```ruby
Status.sync_table_data!
```

This will add any missing records to the table and update the attributes of any records that don't match the values in the data files. Records that do not appear in the data files will not be touched. Any attributes not specified in the data files will not be changed.

### Helper Methods

You can use the `define_instances_from` to define helper methods on your class based on attribute values. In our example, there would be three class methods defined to load records by name

```ruby
Status.pending # Status.find_by(name: "Pending")
Status.in_progress # Status.find_by(name: "In Progress")
Status.completed # Status.find_by(name: "Completed")
```

You can use `` to define predicate methods that test the attribute for a specific value. In our example, there would be three instance methods:

```ruby
status.pending? # status.name == "Pending"
status.in_progress? # status.name == "In Progress"
status.completed? # status.name == "Completed"
```

You can control which helper methods are defined by adding the `only` or `except` argument,

```
  define_instances_from :name, only: [:in_progress, :completed]
  define_predicates_from :name, except: [:pending?]
```

### Caching

You can use the companion [support_table_cache gem](https://github.com/bdurand/support_table_cache) to add caching support to your models so that you don't need to constantly query the database for records that will never change.

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

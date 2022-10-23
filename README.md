# Support Table Data

[![Continuous Integration](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

This gem provides a mixin for ActiveRecord support table models that allows you to load data from YAML, JSON, or CSV files and reference specific records more easily. It is intended to solve issues with support tables (also known as lookup tables) that contain a small set of canonical data that must exist for your application to work.

These kinds of models blur the line between data and code. You'll often end up with constants and application logic based on specific values that need to exist in the table. By using this gem, you can easily define methods for loading and comparing specific instances. This can give you cleaner code that reads far more naturally. You can also avoid defining dozens of constants or referencing magic values (i.e. no more hard-coded strings or ids in the code to look up specific records).

## Usage

In the examples below, suppose we have a simple `Status` model in which each row has an id and a name, and the name can only have a handful of statuses: "Pending", "In Progress", and "Completed".

Now, we may have code that needs to reference the status and make decisions based on it. This will require that the table have the exact same values in it in every environment. This gem lets you define these values in a YAML file:

```yaml
- id: 1
  name: Pending

- id: 2
  name: In Progress

- id: 3
  name: Completed
```

You can then use this mixin to match that data with your model:

```ruby
class Status < ApplicationRecord
  include SupportTableData

  # Set the default location for data files. (This is the default value in a Rails application.)
  self.support_table_data_directory = Rails.root + "db" + "support_tables"

  # Add the data file to the model; you can also specify an absolute path and add multiple data files.
  add_support_table_data "statuses.yml"
end
```

### Specifying Data Files

You use the `add_support_table_data` class method to add a data file path. This file must be a YAML, JSON, or CSV file that defines a list of attributes. YAML and JSON files should contain an array where each element is a hash of the attributes for each record. YAML and JSON file can also be defined as a hash when using named instances (see below). CSV files must use comma delimiters, double quotes for the quote character, and have a header row containing the attribute names.

One of the attributes in your data files will be the key attribute. This attribute must uniquely identify each element. By default, the key attribute will be the table's primary key. You can change this by setting the `support_table_key_attribute` class attribute on the model.

```ruby
class Status < ApplicationRecord
  include SupportTableData
  
  self.support_table_key_attribute = :name
 end
```

You cannot update the value of the key attribute in a record in the data file. If you do, a new record will be created and the existing record will be left unchanged.

You can specify data files as relative paths. This can be done by setting the `SupportTableData.data_directory` value. You can override this value for a model by setting the `support_table_data_directory` attribute on its class. In a Rails application, `SupportTableData.data_directory` will be automatically set to `db/support_tables/`. Otherwise, relative file paths will be resolved from the current working directory. You must define the directory to load relative files from before loading your model classes.

### Named Instances

You can also automatically define helper methods to load instances and determine if they match specific values. This allows you to add more natural ways of referencing specific records.

Named instances are defined if you supply a hash instead of an array in the data files. The hash keys must be valid Ruby method names. Keys that begin with an underscore will not be used to generate named instances. If you only want to create named instances on a few rows in a table, you can add them to an array under an underscored key.

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

The hash keys will be used to define helper methods to load and test for specific instances. In this example, our model defines these methods that make it substantially more natural to reference specific instances.

```ruby
# These methods can be used to load specific instances.
Status.pending      # Status.find_by!(id: 1)
Status.in_progress  # Status.find_by!(id: 2)
Status.completed    # Status.find_by!(id: 3)

# These methods can be used to test for specific instances.
status.pending?     # status.id == 1
status.in_progress? # status.id == 2
status.completed?   # status.id == 3
```

Helper methods will not override already defined methods on a model class. If a method is already defined, an `ArgumentError` will be raised.

### Caching

You can use the companion [support_table_cache gem](https://github.com/bdurand/support_table_cache) to add caching support to your models. That way your application won't need to constantly query the database for records that will never change.

```
class Status < ApplicationRecord
  include SupportTableData
  include SupportTableCache

  add_support_table_data "statuses.yml"

  # Cache lookups when finding by name or by id.
  cache_by :name
  cache_by :id

  # Cache records in local memory instead of a shared cache for best performance.
  self.support_table_cache = :memory
end

class Thing < ApplicationRecord
  belongs_to :status

  # Use caching to load the association rather than hitting the database every time.
  cache_belongs_to :status
end
```

### Loading Data

Calling `sync_table_data!` on your model classes will synchronize the data in your database table with the values from the data files.

```ruby
Status.sync_table_data!
```

This will add any missing records to the table and update existing records so that the attributes in the table match the values in the data files. Records that do not appear in the data files will not be touched. Any attributes not specified in the data files will not be changed.

The number of records contained in data files should be fairly small (ideally fewer than 100). It is possible to load just a subset of rows in a large table because only rows listed in the data files will be synced. You can use this feature if your table allows user-entered data, but has a few rows that must exist for the code to work.

Loading the data is done inside a database transaction. No changes will be persisted to the database unless all rows for a model are able to be synced.

You can synchronize all models by calling `SupportTableData.sync_all!`. This method will discover all ActiveRecord models that include `SupportTableData` and synchronize each of them. Note that the model classes must already be loaded prior to calling `SupportTableData.sync_all!`. This method will produce inconsistent results in a Rails application in development mode because classes will only be loaded once they have been referenced at runtime.

You need to call `SupportTableData.sync_all!` when deploying your application. This gem includes a rake task `support_table_data:sync` to do this that is suitable for hooking into deploy scripts. An easy way to hook it into a Rails application is by enhancing the `db:migrate` task so that the sync task runs after database migrations are run. You can do this by adding code to a Rakefile in your applications `lib/tasks` directory:

```ruby
if Rake::Task.task_defined?("db:migrate")
  Rake::Task["db:migrate"].enhance do
    Rake::Task["support_table_data:sync"].invoke
  end
end
```

Enhancing the `db:migrate` task also ensures that local development environments will stay up to date.

You should also call `SupportTableData.sync_all!` before running your test suite. It should be called once in test suite setup code before any tests are run.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "support_table_data"
```

Then execute:
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

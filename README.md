# Support Table Data

[![Continuous Integration](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/support_table_data/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/support_table_data.svg)](https://badge.fury.io/rb/support_table_data)

This gem provides a mixin for ActiveRecord support table models that allows you to load data from YAML, JSON, or CSV files and reference specific records more easily. It is intended to solve issues with support tables (also known as lookup tables) that contain a small set of canonical data that must exist for your application to work.

These kinds of models blur the line between data and code. You'll often end up with constants and application logic based on specific values that need to exist in the table. By using this gem, you can easily define methods for loading and comparing specific instances. This can give you cleaner code that reads far more naturally. You can also avoid defining dozens of constants or referencing magic values (i.e. no more hard-coded strings or ids in the code to look up specific records).

## Table of Contents

- [Usage](#usage)
  - [Specifying Data Files](#specifying-data-files)
  - [Named Instances](#named-instances)
    - [Documenting Named Instance Helpers](#documenting-named-instance-helpers)
  - [Caching](#caching)
  - [Loading Data](#loading-data)
  - [Testing](#testing)
- [Installation](#installation)
- [Contributing](#contributing)
- [License](#license)

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

You can specify data files as relative paths. This can be done by setting the `SupportTableData.data_directory` value. You can override this value for a model by setting the `support_table_data_directory` attribute on its class. Otherwise, relative file paths will be resolved from the current working directory. You must define the directory to load relative files from before loading your model classes.

In a Rails application, `SupportTableData.data_directory` will be automatically set to `db/support_tables/`. This can be overridden by setting the `config.support_table.data_directory` option in the Rails application configuration.

**Note**: If you're using CSV files and Ruby 3.4 or higher, you'll need to include the `csv` gem in your Gemfile since it was removed from the standard library in Ruby 3.4.

### Named Instances

You can also automatically define helper methods to load instances and determine if they match specific values. This allows you to add more natural ways of referencing specific records.

Named instances are defined if you supply a hash instead of an array in the data files. The hash keys must be valid Ruby method names. Keys that begin with an underscore will not be used to generate named instances. If you only want to create named instances on a few rows in a table, you can add them to an array under an underscored key.

Here is an example data file using named instances:

```yaml
pending:
  id: 1
  name: Pending
  icon: clock

in_progress:
  id: 2
  name: In Progress
  icon: construction

completed:
  id: 3
  name: Completed
  icon: heavy_check_mark

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

You can also define helper methods for named instance attributes. These helper methods will return the hard coded values from the data file. Calling these methods does not require a database connection.

```ruby
class Status < ApplicationRecord
  include SupportTableData

  named_instance_attribute_helpers :id
end

Status.pending_id     # => 1
Status.in_progress_id # => 2
Status.completed_id   # => 3
```

You can also use named instances to maintain associations between you models. In order to do this you'll need to implement a custom setter method.

```ruby
class Group < ApplicationRecord
  include SupportTableData

  has_many :statuses
end

class Status < ApplicationRecord
  include SupportTableData

  belongs_to :group

  def group_name=(instance_name)
    self.group = Group.named_instance(instance_name)
  end
end
```

This then allows you to reference groups by instance name in the statuses.yml file:

```yaml
# groups.yml
not_done:
  id: 1
  name: Not Done

done:
  id: 2
  name: Done

# statuses.yml
pending:
  id: 1
  name: Pending
  group_name: not_done

in_progress:
  id: 2
  name: In Progress
  group_name: not_done

completed:
  id: 3
  name: Completed
  group_name: done
```

#### Documenting Named Instance Helpers

In a Rails application, you can add YARD documentation for the named instance helpers by running the rake task `support_table_data:add_yard_docs`. This will add YARD comments to your model classes for each of the named instance helper methods defined on the model. Adding this documentation will help IDEs provide better code completion and inline documentation for the helper methods and expose the methods to AI agents.

The default behavior is to add the documentation comments at the end of the model class by reopening the class definition. If you prefer to have the documentation comments appear elsewhere in the file, you can add the following markers to your model class and the YARD documentation will be inserted between these markers.

```ruby
# Begin YARD docs for support_table_data
# End YARD docs for support_table_data
```

A good practice is to add a check to your CI pipeline to ensure the documentation is always up to date. You can run the rake task `support_table_data:verify_yard_docs` to do this. It will exit with an error if any models do not have up to date documentation.

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

> [!TIP]
> The [support_table](https://github.com/bdurand/support_table) gem combines both gems in a drop in solution for Rails applications.

### Loading Data

Calling `sync_table_data!` on your model class will synchronize the data in the database table with the values from the data files.

```ruby
Status.sync_table_data!
```

This will add any missing records to the table and update existing records so that the attributes in the table match the values in the data files. Records that do not appear in the data files will not be touched. Any attributes not specified in the data files will not be changed.

The number of records contained in data files should be fairly small (ideally fewer than 100). It is possible to load just a subset of rows in a large table because only the rows listed in the data files will be synced. You can use this feature if your table allows user-entered data, but has a few rows that must exist for the code to work.

Loading data is done inside a database transaction. No changes will be persisted to the database unless all rows for a model can be synced.

You can synchronize the data in all models by calling `SupportTableData.sync_all!`. This method will discover all ActiveRecord models that include `SupportTableData` and synchronize each of them. (Note that there can be issues discovering all support table models in a Rails application if eager loading is turned off.) The discovery mechanism will try to detect unloaded classes by looking at the file names in the support table data directory so it's best to stick to standard Rails naming conventions for your data files.

The load order for models will resolve any dependencies between models. So if one model has a `belongs_to` association with another model, then the belongs to model will be loaded first. You can also explicitly define dependencies with the `support_table_dependency` method. If you have a join table between support tables that creates a circular dependency, then you will need to define which model to load first.

```ruby
class Widget < ApplicationRecord
  include SupportTableData

  add_support_table_data "widgets.yml"

  has_many :thing_widgets
  has_many :things, through: :thing_widgets
end

class Thing < ApplicationRecord
  include SupportTableData

  add_support_table_data "things.yml"

  has_many :thing_widgets
  has_many :widgets, through: :thing_widgets, autosave: true

  # The Thing model is responsible for loading the thing_widgets join table by means of the widget_names=
  # setter method. We need to define the depdenency to ensure widgets are loaded first.
  support_table_dependency "Widget"

  def widget_names=(widget_names)
    self.widgets = Widget.where(name: widget_names)
  end
end
```

If you use a method to set a `has_many` association on your model, you **must** set the `autosave` option to `true` on the association (see the above example). This will ensure the association records are always saved even if there were no changes to the parent record.

You will need to call `SupportTableData.sync_all!` when deploying your application or running your test suite. This gem includes a rake task `support_table_data:sync` that is suitable for hooking into deploy or CI scripts.

This task is automatically run whenever you run any of these Rails tasks so if these are already part of your deploy or CI scripts, then no additional setup is required:

- `db:seed`
- `db:seed:replant`
- `db:prepare`
- `db:test:prepare`
- `db:fixtures:load`

You can disable these task enhancements by setting `config.support_table.auto_sync = false` in your Rails application configuration.

> [!TIP]
> If you also want to hook into the `db:migrate` task so that syncs are run immediately after database migrations, you can do this by adding code to a Rakefile in your application's `lib/tasks` directory. Migrations do funny things with the database connection especially when using multiple databases so you need to re-establish the connection before syncing the support table data.

```ruby
if Rake::Task.task_defined?("db:migrate")
  Rake::Task["db:migrate"].enhance do
    # The main database connection may have artifacts from the migration, so re-establish it
    # to get a clean connection before syncing support table data.
    ActiveRecord::Base.establish_connection

    Rake::Task["support_table_data:sync"].invoke
  end
end
```

### Testing

You must also call `SupportTableData.sync_all!` before running your test suite. This method should be called in the test suite setup code after any data in the test database has been purged and before any tests are run.

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

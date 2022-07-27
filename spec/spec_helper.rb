require "bundler/setup"

require "active_record"

ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")

require_relative "../lib/support_table_data"

class Color < ActiveRecord::Base
  unless table_exists?
    connection.create_table(table_name) do |t|
      t.string :name
      t.integer :value
      t.string :comment
    end
  end

  include SupportTableData

  self.support_table_directory = __dir__
  add_support_table_data("colors.yml")
  add_support_table_data("colors.json")

  define_instances_from :name
  define_predicates_from :name

  def hex=(value)
    self.value = value.to_i(16)
  end
end

RSpec.configure do |config|
  config.before do
    Color.delete_all
  end
end

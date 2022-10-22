require "bundler/setup"

require "active_record"

ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")

require_relative "../lib/support_table_data"

SupportTableData.data_directory = File.join(__dir__, "data")

class Color < ActiveRecord::Base
  unless table_exists?
    connection.create_table(table_name) do |t|
      t.string :name, index: {unique: true}
      t.integer :value
      t.string :comment
      t.integer :group_id
      t.integer :hue_id
    end
  end

  include SupportTableData

  self.support_table_data_directory = File.join(__dir__, "data", "colors")
  add_support_table_data "named_colors.yml"
  add_support_table_data "named_colors.json"
  add_support_table_data "colors.yml"
  add_support_table_data File.join(__dir__, "data", "colors", "colors.json")
  add_support_table_data "colors.csv"

  belongs_to :group
  belongs_to :hue

  validates_uniqueness_of :name

  def group_name=(value)
    self.group = Group.find_by!(name: value)
  end

  def hue_name=(value)
    self.hue = Hue.find_by!(name: value)
  end

  private

  def hex=(value)
    self.value = value.to_i(16)
  end
end

class Group < ActiveRecord::Base
  unless table_exists?
    connection.create_table(table_name) do |t|
      t.string :name, index: {unique: true}
      t.timestamps
    end
  end

  include SupportTableData

  add_support_table_data "groups.yml"

  validates_uniqueness_of :name
end

class Hue < ActiveRecord::Base
  unless table_exists?
    connection.create_table(table_name) do |t|
      t.string :name, index: {unique: true}
      t.integer :parent_id
    end
  end

  include SupportTableData

  self.support_table_key_attribute = "name"

  add_support_table_data "hues.yml"

  belongs_to :parent, class_name: "Hue", optional: true

  validates_uniqueness_of :name

  def parent_name=(value)
    self.parent = Hue.find_by!(name: value)
  end
end

class Thing < ActiveRecord::Base
  unless table_exists?
    connection.create_table(table_name) do |t|
      t.string :name
      t.integer :color_id
    end
  end

  belongs_to :color
end

RSpec.configure do |config|
  config.before do
    Thing.delete_all
    Hue.delete_all
    Group.delete_all
    Color.delete_all
  end
end

require "bundler/setup"

require "active_record"

ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")

require_relative "../lib/support_table_data"

SupportTableData.data_directory = File.join(__dir__, "data")

ActiveRecord::Base.connection.tap do |connection|
  connection.create_table(:colors) do |t|
    t.string :name, index: {unique: true}
    t.integer :value
    t.string :comment
    t.integer :group_id
    t.integer :hue_id
  end

  connection.create_table(:groups, primary_key: :group_id) do |t|
    t.string :name, index: {unique: true}
    t.timestamps
  end

  connection.create_table(:hues) do |t|
    t.string :name, index: {unique: true}
    t.integer :parent_id
  end

  connection.create_table(:shades) do |t|
    t.string :name
  end

  connection.create_table(:shade_hues) do |t|
    t.integer :shade_id
    t.integer :hue_id
  end

  connection.create_table(:things) do |t|
    t.string :name
    t.integer :color_id
    t.integer :shade_id
  end

  connection.create_table(:aliases) do |t|
    t.string :name
    t.integer :color_id
  end

  connection.create_table(:invalids) do |t|
    t.string :name
  end
end

class Color < ActiveRecord::Base
  include SupportTableData

  self.support_table_data_directory = File.join(__dir__, "data", "colors")
  add_support_table_data "named_colors.yml"
  add_support_table_data "named_colors.json"
  add_support_table_data "colors.yml"
  add_support_table_data File.join(__dir__, "data", "colors", "colors.json")
  add_support_table_data "colors.csv"

  belongs_to :group
  belongs_to :hue
  has_many :things
  has_many :shades, through: :things
  has_many :aliases, autosave: true

  # Intentionally invalid association
  belongs_to :non_existent, class_name: "NonExistent"

  validates_uniqueness_of :name

  def group_name=(value)
    self.group = Group.named_instance(value)
  end

  def hue_name=(value)
    self.hue = Hue.find_by!(name: value)
  end

  def alias_names=(names)
    self.aliases = names.map { |name| Alias.find_or_initialize_by(name: name) }
  end

  private

  def hex=(value)
    self.value = value.to_i(16)
  end
end

class Alias < ActiveRecord::Base
  belongs_to :color

  validates_uniqueness_of :name
end

class Group < ActiveRecord::Base
  include SupportTableData

  self.primary_key = :group_id

  named_instance_attribute_helpers :group_id

  add_support_table_data "groups.yml"

  named_instance_attribute_helpers :name

  validates_uniqueness_of :name
end

class Hue < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :name

  add_support_table_data "hues.yml"

  belongs_to :parent, class_name: "Hue", optional: true

  validates_uniqueness_of :name

  def parent_name=(value)
    self.parent = Hue.find_by!(name: value)
  end

  has_many :shade_hues
  has_many :shades, through: :shade_hues, autosave: true

  support_table_dependency "Shade"

  def shade_names=(names)
    self.shades = Shade.where(name: names)
  end
end

class Shade < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :name

  add_support_table_data "shades.yml"

  validates_uniqueness_of :name

  has_many :shade_hues
  has_many :hues, through: :shade_hues
end

class ShadeHue < ActiveRecord::Base
  belongs_to :shade
  belongs_to :hue
end

class Thing < ActiveRecord::Base
  belongs_to :color
  belongs_to :shade
end

class Invalid < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :name

  def already_defined?
    true
  end
end

RSpec.configure do |config|
  config.order = :random

  config.before do
    Thing.delete_all
    Hue.delete_all
    Group.delete_all
    Color.delete_all
  end
end

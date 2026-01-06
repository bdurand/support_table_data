# frozen_string_literal: true

class Color < ActiveRecord::Base
  include SupportTableData

  self.support_table_data_directory = File.join(__dir__, "..", "data", "colors")
  add_support_table_data "named_colors.yml"
  add_support_table_data "named_colors.json"
  add_support_table_data "colors.yml"
  add_support_table_data File.join(__dir__, "..", "data", "colors", "colors.json")
  add_support_table_data "colors.csv"

  belongs_to :group
  belongs_to :hue
  has_many :things
  has_many :shades, through: :things
  has_many :aliases, autosave: true

  # Intentionally invalid association
  belongs_to :non_existent, class_name: "NonExistent"

  validates :name, presence: true, uniqueness: true

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

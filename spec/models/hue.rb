# frozen_string_literal: true

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

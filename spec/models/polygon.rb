# frozen_string_literal: true

class Polygon < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :name

  add_support_table_data "polygons.yml"

  validates :name, uniqueness: true
end

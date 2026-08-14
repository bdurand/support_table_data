# frozen_string_literal: true

class Shape < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :name

  add_support_table_data "shapes.yml"
end

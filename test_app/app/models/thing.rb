# frozen_string_literal: true

class Thing < SecondaryApplicationRecord
  include SupportTableData

  self.support_table_key_attribute = :id
  add_support_table_data "things.yml"

  validates :name, presence: true, uniqueness: true
end

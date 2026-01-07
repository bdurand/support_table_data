# frozen_string_literal: true

class Group < ActiveRecord::Base
  include SupportTableData

  self.primary_key = :group_id

  self.support_table_key_attribute = :group_id
  named_instance_attribute_helpers :group_id

  add_support_table_data "groups.yml"

  named_instance_attribute_helpers :name

  validates_uniqueness_of :name
end

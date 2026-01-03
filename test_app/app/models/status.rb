# frozen_string_literal: true

class Status < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :code
  add_support_table_data "statuses.yml"
  named_instance_attribute_helpers :name
end

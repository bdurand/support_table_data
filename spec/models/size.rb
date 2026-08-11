# frozen_string_literal: true

class Size < ActiveRecord::Base
  include SupportTableData

  named_instance_attribute_helpers :label, :introduced_on

  add_support_table_data "sizes.yml"
  add_support_table_data "sizes_override.yml"
end

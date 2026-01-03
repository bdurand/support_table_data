# frozen_string_literal: true

class Invalid < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :name

  def already_defined?
    true
  end
end

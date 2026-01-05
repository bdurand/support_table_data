# frozen_string_literal: true

class Shade < ActiveRecord::Base
  include SupportTableData

  self.support_table_key_attribute = :name

  add_support_table_data "shades.yml"

  validates_uniqueness_of :name

  has_many :shade_hues
  has_many :hues, through: :shade_hues
end

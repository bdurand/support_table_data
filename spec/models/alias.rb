# frozen_string_literal: true

class Alias < ActiveRecord::Base
  belongs_to :color

  validates_uniqueness_of :name
end

# frozen_string_literal: true

class Thing < ActiveRecord::Base
  belongs_to :color
  belongs_to :shade
end

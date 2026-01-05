# frozen_string_literal: true

class ShadeHue < ActiveRecord::Base
  belongs_to :shade
  belongs_to :hue
end

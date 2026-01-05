# frozen_string_literal: true

class Rectangle < Polygon
  validates :side_count, numericality: {equal_to: 4}
end

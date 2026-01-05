# frozen_string_literal: true

class Triangle < Polygon
  validates :side_count, numericality: {equal_to: 3}
end

ActiveRecord::Base.connection.tap do |connection|
  connection.create_table(:colors) do |t|
    t.string :name, index: {unique: true}
    t.integer :value
    t.string :comment
    t.integer :group_id
    t.integer :hue_id
  end

  connection.create_table(:groups, primary_key: :group_id) do |t|
    t.string :name, index: {unique: true}
    t.timestamps
  end

  connection.create_table(:hues) do |t|
    t.string :name, index: {unique: true}
    t.integer :parent_id
  end

  connection.create_table(:shades) do |t|
    t.string :name
  end

  connection.create_table(:shade_hues) do |t|
    t.integer :shade_id
    t.integer :hue_id
  end

  connection.create_table(:things) do |t|
    t.string :name
    t.integer :color_id
    t.integer :shade_id
  end

  connection.create_table(:aliases) do |t|
    t.string :name
    t.integer :color_id
  end

  connection.create_table(:invalids) do |t|
    t.string :name
  end

  connection.create_table(:polygons) do |t|
    t.string :name
    t.string :type
    t.integer :side_count
  end
end

# Lazy load model classes
autoload :Alias, File.expand_path("models/alias.rb", __dir__)
autoload :Color, File.expand_path("models/color.rb", __dir__)
autoload :Group, File.expand_path("models/group.rb", __dir__)
autoload :Hue, File.expand_path("models/hue.rb", __dir__)
autoload :Invalid, File.expand_path("models/invalid.rb", __dir__)
autoload :Polygon, File.expand_path("models/polygon.rb", __dir__)
autoload :Rectangle, File.expand_path("models/rectangle.rb", __dir__)
autoload :Shade, File.expand_path("models/shade.rb", __dir__)
autoload :ShadeHue, File.expand_path("models/shade_hue.rb", __dir__)
autoload :Thing, File.expand_path("models/thing.rb", __dir__)
autoload :Triangle, File.expand_path("models/triangle.rb", __dir__)

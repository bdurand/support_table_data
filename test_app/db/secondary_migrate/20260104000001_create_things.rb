class CreateThings < ActiveRecord::Migration[8.1]
  def change
    create_table :things do |t|
      t.string :name, null: false, index: {unique: true}
    end
  end
end

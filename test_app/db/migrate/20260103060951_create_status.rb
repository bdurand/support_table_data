class CreateStatus < ActiveRecord::Migration[8.1]
  def change
    create_table :statuses do |t|
      t.string :code, null: false, index: {unique: true}
      t.string :name, null: false, index: {unique: true}
    end
  end
end

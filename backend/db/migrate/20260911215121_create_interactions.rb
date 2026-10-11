class CreateInteractions < ActiveRecord::Migration[8.1]
  def change
    create_table :interactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.string :event_type, null: false
      t.integer :duration_ms

      t.timestamps
    end

    add_index :interactions, [ :post_id, :event_type ]
  end
end

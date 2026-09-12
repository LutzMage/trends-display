class CreateFeedItems < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.float :score, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :feed_items, [ :user_id, :position ], unique: true
  end
end

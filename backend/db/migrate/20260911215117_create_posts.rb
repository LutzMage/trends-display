class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :text, limit: 250, null: false
      t.string :media_type
      t.string :media_url

      t.timestamps
    end
  end
end

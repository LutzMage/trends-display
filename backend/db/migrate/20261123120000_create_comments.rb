class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      # Indexed below together with created_at, for the newest-first list.
      t.references :post, null: false, foreign_key: true, index: false
      t.string :body, limit: 250, null: false
      t.timestamps

      t.index [ :post_id, :created_at ]
    end
  end
end

class CreateEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :embeddings do |t|
      t.references :embeddable, polymorphic: true, null: false
      t.string :embedding_type, null: false
      t.string :embedding_model, null: false
      t.integer :dimensions, null: false
      t.vector :vector, limit: 768, null: false

      t.timestamps
    end

    add_index :embeddings, [ :embeddable_type, :embeddable_id, :embedding_type ], name: "index_embeddings_on_embeddable_and_type"
  end
end

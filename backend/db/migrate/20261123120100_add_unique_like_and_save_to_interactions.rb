class AddUniqueLikeAndSaveToInteractions < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_interactions_one_like_or_save"

  # Like and save become states, one per user and post (SPEC-003 §4.1). Other event types stay a log.
  DELETE_DUPLICATES = <<~SQL.freeze
    DELETE FROM interactions newer
    USING interactions older
    WHERE newer.event_type IN ('like', 'save')
      AND older.user_id = newer.user_id
      AND older.post_id = newer.post_id
      AND older.event_type = newer.event_type
      AND (older.created_at, older.id) < (newer.created_at, newer.id)
  SQL

  def up
    # Keeps the oldest row of each duplicate group. Not reversible: down does not restore them.
    removed = exec_delete(DELETE_DUPLICATES)
    say "Removed #{removed} duplicate like/save interactions"

    add_index :interactions, [ :user_id, :post_id, :event_type ],
      unique: true, where: "event_type IN ('like', 'save')", name: INDEX_NAME
  end

  def down
    remove_index :interactions, name: INDEX_NAME
  end
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_11_215144) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "embeddings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "dimensions", null: false
    t.bigint "embeddable_id", null: false
    t.string "embeddable_type", null: false
    t.string "embedding_model", null: false
    t.string "embedding_type", null: false
    t.datetime "updated_at", null: false
    t.vector "vector", limit: 768, null: false
    t.index ["embeddable_type", "embeddable_id", "embedding_type"], name: "index_embeddings_on_embeddable_and_type"
    t.index ["embeddable_type", "embeddable_id"], name: "index_embeddings_on_embeddable"
  end

  create_table "feed_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.bigint "post_id", null: false
    t.float "score", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["post_id"], name: "index_feed_items_on_post_id"
    t.index ["user_id", "position"], name: "index_feed_items_on_user_id_and_position", unique: true
    t.index ["user_id"], name: "index_feed_items_on_user_id"
  end

  create_table "interactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "event_type", null: false
    t.bigint "post_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["post_id", "event_type"], name: "index_interactions_on_post_id_and_event_type"
    t.index ["post_id"], name: "index_interactions_on_post_id"
    t.index ["user_id"], name: "index_interactions_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "media_type"
    t.string "media_url"
    t.string "text", limit: 250, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "feed_items", "posts"
  add_foreign_key "feed_items", "users"
  add_foreign_key "interactions", "posts"
  add_foreign_key "interactions", "users"
  add_foreign_key "posts", "users"
end

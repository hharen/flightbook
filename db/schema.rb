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

ActiveRecord::Schema[8.0].define(version: 2025_10_27_192430) do
  create_table "flights", force: :cascade do |t|
    t.float "duration"
    t.string "note"
    t.integer "flying_session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["flying_session_id"], name: "index_flights_on_flying_session_id"
  end

  create_table "flying_sessions", force: :cascade do |t|
    t.datetime "date_time", null: false
    t.string "note"
    t.integer "user_id", null: false
    t.integer "instructor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instructor_id"], name: "index_flying_sessions_on_instructor_id"
    t.index ["user_id"], name: "index_flying_sessions_on_user_id"
  end

  create_table "instructors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "flights", "flying_sessions"
  add_foreign_key "flying_sessions", "instructors"
  add_foreign_key "flying_sessions", "users"
end

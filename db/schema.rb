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

ActiveRecord::Schema[8.0].define(version: 2024_12_21_204956) do
  create_table "teams", force: :cascade do |t|
    t.integer "cfbd_id"
    t.string "school"
    t.string "mascot"
    t.string "abbreviation"
    t.json "alternate_names"
    t.string "conference"
    t.string "color"
    t.string "alternate_color"
    t.json "logos"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "venues", force: :cascade do |t|
    t.integer "cfbd_id"
    t.string "name"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.string "country_code"
    t.string "timezone"
    t.integer "capacity"
    t.integer "construction_year"
    t.boolean "grass"
    t.boolean "dome"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end

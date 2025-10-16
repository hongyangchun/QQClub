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

ActiveRecord::Schema[8.0].define(version: 2025_10_16_121915) do
  create_table "check_ins", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "reading_schedule_id", null: false
    t.integer "enrollment_id", null: false
    t.text "content", null: false
    t.integer "word_count", default: 0
    t.integer "status", default: 0
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id"], name: "index_check_ins_on_enrollment_id"
    t.index ["reading_schedule_id"], name: "index_check_ins_on_reading_schedule_id"
    t.index ["user_id", "reading_schedule_id"], name: "index_check_ins_on_user_id_and_reading_schedule_id", unique: true
    t.index ["user_id"], name: "index_check_ins_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "content"
    t.integer "post_id"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "commentable_type"
    t.integer "commentable_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["created_at"], name: "index_comments_on_created_at"
    t.index ["post_id", "created_at"], name: "index_comments_on_post_id_and_created_at"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "daily_leadings", force: :cascade do |t|
    t.integer "reading_schedule_id", null: false
    t.integer "leader_id", null: false
    t.text "reading_suggestion", null: false
    t.text "questions", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["leader_id"], name: "index_daily_leadings_on_leader_id"
    t.index ["reading_schedule_id"], name: "index_daily_leadings_on_reading_schedule_id", unique: true
  end

  create_table "enrollments", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "reading_event_id", null: false
    t.integer "payment_status", default: 0
    t.integer "role", default: 0
    t.integer "leading_count", default: 0
    t.decimal "paid_amount", precision: 8, scale: 2
    t.decimal "refund_amount", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reading_event_id"], name: "index_enrollments_on_reading_event_id"
    t.index ["user_id", "reading_event_id"], name: "index_enrollments_on_user_id_and_reading_event_id", unique: true
    t.index ["user_id"], name: "index_enrollments_on_user_id"
  end

  create_table "flowers", force: :cascade do |t|
    t.integer "check_in_id", null: false
    t.integer "giver_id", null: false
    t.integer "recipient_id", null: false
    t.integer "reading_schedule_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_in_id"], name: "index_flowers_on_check_in_id", unique: true
    t.index ["giver_id"], name: "index_flowers_on_giver_id"
    t.index ["reading_schedule_id", "giver_id"], name: "index_flowers_on_reading_schedule_id_and_giver_id"
    t.index ["reading_schedule_id"], name: "index_flowers_on_reading_schedule_id"
    t.index ["recipient_id"], name: "index_flowers_on_recipient_id"
  end

  create_table "likes", force: :cascade do |t|
    t.string "target_type"
    t.integer "target_id"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.integer "user_id", null: false
    t.boolean "pinned", default: false
    t.boolean "hidden", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.json "images"
    t.json "tags"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "reading_events", force: :cascade do |t|
    t.string "title", null: false
    t.string "book_name", null: false
    t.string "book_cover_url"
    t.text "description"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.integer "max_participants", default: 30
    t.decimal "enrollment_fee", precision: 8, scale: 2, default: "100.0"
    t.integer "status", default: 0
    t.integer "leader_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "leader_assignment_type"
    t.integer "approval_status"
    t.integer "approved_by_id"
    t.datetime "approved_at"
    t.index ["approved_by_id"], name: "index_reading_events_on_approved_by_id"
    t.index ["leader_id"], name: "index_reading_events_on_leader_id"
    t.index ["start_date"], name: "index_reading_events_on_start_date"
    t.index ["status"], name: "index_reading_events_on_status"
  end

  create_table "reading_schedules", force: :cascade do |t|
    t.integer "reading_event_id", null: false
    t.integer "day_number", null: false
    t.date "date", null: false
    t.string "reading_progress", null: false
    t.integer "daily_leader_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_leader_id"], name: "index_reading_schedules_on_daily_leader_id"
    t.index ["date"], name: "index_reading_schedules_on_date"
    t.index ["reading_event_id", "day_number"], name: "index_reading_schedules_on_reading_event_id_and_day_number", unique: true
    t.index ["reading_event_id"], name: "index_reading_schedules_on_reading_event_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "wx_openid", null: false
    t.string "wx_unionid"
    t.string "nickname"
    t.string "avatar_url"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0
    t.index ["role"], name: "index_users_on_role"
    t.index ["wx_openid"], name: "index_users_on_wx_openid", unique: true
    t.index ["wx_unionid"], name: "index_users_on_wx_unionid", unique: true
  end

  add_foreign_key "check_ins", "enrollments"
  add_foreign_key "check_ins", "reading_schedules"
  add_foreign_key "check_ins", "users"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "daily_leadings", "reading_schedules"
  add_foreign_key "daily_leadings", "users", column: "leader_id"
  add_foreign_key "enrollments", "reading_events"
  add_foreign_key "enrollments", "users"
  add_foreign_key "flowers", "check_ins"
  add_foreign_key "flowers", "reading_schedules"
  add_foreign_key "flowers", "users", column: "giver_id"
  add_foreign_key "flowers", "users", column: "recipient_id"
  add_foreign_key "likes", "users"
  add_foreign_key "posts", "users"
  add_foreign_key "reading_events", "users", column: "approved_by_id"
  add_foreign_key "reading_events", "users", column: "leader_id"
  add_foreign_key "reading_schedules", "reading_events"
  add_foreign_key "reading_schedules", "users", column: "daily_leader_id"
end

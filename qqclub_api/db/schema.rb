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

ActiveRecord::Schema[8.0].define(version: 2025_10_17_150100) do
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
    t.integer "flowers_count", default: 0, null: false
    t.integer "comments_count", default: 0, null: false
    t.index ["enrollment_id", "created_at"], name: "index_check_ins_on_enrollment_created"
    t.index ["enrollment_id"], name: "index_check_ins_on_enrollment_id"
    t.index ["reading_schedule_id", "created_at"], name: "index_check_ins_on_schedule_created"
    t.index ["reading_schedule_id", "status", "created_at"], name: "index_checkins_schedule_status_created"
    t.index ["reading_schedule_id"], name: "index_check_ins_on_reading_schedule_id"
    t.index ["user_id", "created_at"], name: "index_check_ins_on_user_created"
    t.index ["user_id", "reading_schedule_id", "created_at"], name: "index_checkins_user_schedule_created"
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
    t.index ["commentable_type", "commentable_id", "created_at"], name: "index_comments_on_commentable_created"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
    t.index ["created_at"], name: "index_comments_on_created_at"
    t.index ["post_id", "created_at"], name: "index_comments_on_post_created_optimized"
    t.index ["post_id", "created_at"], name: "index_comments_on_post_id_and_created_at"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id", "created_at"], name: "index_comments_on_user_created"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "content_reports", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "check_in_id", null: false
    t.integer "admin_id"
    t.string "reason", default: "other", null: false
    t.text "description"
    t.string "status", default: "pending", null: false
    t.text "admin_notes"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_content_reports_on_admin_id"
    t.index ["check_in_id"], name: "index_content_reports_on_check_in_id"
    t.index ["created_at"], name: "index_content_reports_on_created_at"
    t.index ["reason"], name: "index_content_reports_on_reason"
    t.index ["status"], name: "index_content_reports_on_status"
    t.index ["user_id", "check_in_id"], name: "index_content_reports_unique_reporting", unique: true
    t.index ["user_id"], name: "index_content_reports_on_user_id"
  end

  create_table "daily_flower_stats", force: :cascade do |t|
    t.integer "reading_event_id", null: false
    t.date "stats_date", null: false
    t.json "leaderboard_data", null: false
    t.integer "total_flowers_given", default: 0
    t.integer "total_participants", default: 0
    t.integer "total_givers", default: 0
    t.string "share_image_url"
    t.string "share_text"
    t.integer "share_count", default: 0
    t.datetime "generated_at", null: false
    t.string "generated_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generated_at"], name: "index_daily_flower_stats_on_generated_at"
    t.index ["reading_event_id", "stats_date"], name: "index_daily_flower_stats_unique", unique: true
    t.index ["reading_event_id"], name: "index_daily_flower_stats_on_reading_event_id"
    t.index ["stats_date"], name: "index_daily_flower_stats_on_stats_date"
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

  create_table "event_enrollments", force: :cascade do |t|
    t.integer "reading_event_id", null: false
    t.integer "user_id", null: false
    t.string "enrollment_type", default: "participant", null: false
    t.string "status", default: "enrolled", null: false
    t.datetime "enrollment_date", null: false
    t.decimal "completion_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.integer "check_ins_count", default: 0, null: false
    t.integer "leader_days_count", default: 0, null: false
    t.integer "flowers_received_count", default: 0, null: false
    t.decimal "fee_paid_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "fee_refund_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "refund_status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_date"], name: "index_event_enrollments_on_enrollment_date"
    t.index ["enrollment_type"], name: "index_event_enrollments_on_enrollment_type"
    t.index ["reading_event_id", "status", "enrollment_date"], name: "index_enrollments_event_status_date"
    t.index ["reading_event_id", "status"], name: "index_enrollments_on_event_status"
    t.index ["reading_event_id", "user_id"], name: "index_event_enrollments_on_reading_event_id_and_user_id", unique: true
    t.index ["reading_event_id"], name: "index_event_enrollments_on_reading_event_id"
    t.index ["status"], name: "index_event_enrollments_on_status"
    t.index ["user_id", "status", "enrollment_date"], name: "index_enrollments_user_status_date"
    t.index ["user_id", "status"], name: "index_enrollments_on_user_status"
    t.index ["user_id"], name: "index_event_enrollments_on_user_id"
  end

  create_table "flower_certificates", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "reading_event_id", null: false
    t.integer "rank", null: false
    t.integer "total_flowers", null: false
    t.string "certificate_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certificate_id"], name: "index_flower_certificates_on_certificate_id", unique: true
    t.index ["reading_event_id", "rank"], name: "index_certificates_on_event_rank"
    t.index ["reading_event_id", "rank"], name: "index_flower_certificates_unique_rank", unique: true
    t.index ["reading_event_id"], name: "index_flower_certificates_on_reading_event_id"
    t.index ["user_id", "created_at"], name: "index_certificates_on_user_created"
    t.index ["user_id"], name: "index_flower_certificates_on_user_id"
  end

  create_table "flower_quotas", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "reading_event_id", null: false
    t.integer "used_flowers", default: 0, null: false
    t.integer "max_flowers", default: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "quota_date", null: false
    t.datetime "last_given_at"
    t.integer "give_count_today", default: 0
    t.index ["quota_date"], name: "index_flower_quotas_on_quota_date"
    t.index ["reading_event_id"], name: "index_flower_quotas_on_reading_event_id"
    t.index ["user_id", "reading_event_id", "quota_date"], name: "index_flower_quotas_daily_unique", unique: true
    t.index ["user_id", "reading_event_id", "quota_date"], name: "index_quotas_on_user_event_date"
    t.index ["user_id"], name: "index_flower_quotas_on_user_id"
  end

  create_table "flowers", force: :cascade do |t|
    t.integer "check_in_id", null: false
    t.integer "giver_id", null: false
    t.integer "recipient_id", null: false
    t.integer "reading_schedule_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "amount", default: 1
    t.string "flower_type", default: "regular"
    t.boolean "is_anonymous", default: false
    t.datetime "created_at_for_batch"
    t.index ["check_in_id"], name: "index_flowers_on_check_in_id", unique: true
    t.index ["created_at", "recipient_id"], name: "index_flowers_on_created_recipient"
    t.index ["created_at_for_batch"], name: "index_flowers_on_created_at_for_batch"
    t.index ["flower_type"], name: "index_flowers_on_flower_type"
    t.index ["giver_id", "created_at"], name: "index_flowers_giver_created_optimized"
    t.index ["giver_id", "created_at"], name: "index_flowers_on_giver_created"
    t.index ["giver_id"], name: "index_flowers_on_giver_id"
    t.index ["is_anonymous"], name: "index_flowers_on_is_anonymous"
    t.index ["reading_schedule_id", "created_at"], name: "index_flowers_schedule_created"
    t.index ["reading_schedule_id", "giver_id"], name: "index_flowers_on_reading_schedule_id_and_giver_id"
    t.index ["reading_schedule_id"], name: "index_flowers_on_reading_schedule_id"
    t.index ["recipient_id", "created_at"], name: "index_flowers_on_recipient_created"
    t.index ["recipient_id", "created_at"], name: "index_flowers_recipient_created_optimized"
    t.index ["recipient_id"], name: "index_flowers_on_recipient_id"
  end

  create_table "likes", force: :cascade do |t|
    t.string "target_type"
    t.integer "target_id"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["target_type", "target_id", "created_at"], name: "index_likes_on_polymorphic_created"
    t.index ["target_type", "target_id", "user_id"], name: "index_likes_on_polymorphic_user"
    t.index ["target_type", "target_id"], name: "index_likes_on_polymorphic_target"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "recipient_id", null: false
    t.integer "actor_id", null: false
    t.string "notifiable_type", null: false
    t.integer "notifiable_id", null: false
    t.string "notification_type", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["notification_type", "created_at"], name: "index_notifications_type_created"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["read"], name: "index_notifications_on_read"
    t.index ["recipient_id", "created_at"], name: "index_notifications_on_recipient_created"
    t.index ["recipient_id", "read", "created_at"], name: "index_notifications_on_recipient_read_created"
    t.index ["recipient_id", "read", "created_at"], name: "index_notifications_unread_recent"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "participation_certificates", force: :cascade do |t|
    t.integer "reading_event_id", null: false
    t.integer "user_id", null: false
    t.string "certificate_type", null: false
    t.string "certificate_number", null: false
    t.datetime "issued_at", null: false
    t.text "achievement_data"
    t.string "certificate_url"
    t.boolean "is_public", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["certificate_number"], name: "index_participation_certificates_on_certificate_number", unique: true
    t.index ["certificate_type"], name: "index_participation_certificates_on_certificate_type"
    t.index ["is_public"], name: "index_participation_certificates_on_is_public"
    t.index ["issued_at"], name: "index_participation_certificates_on_issued_at"
    t.index ["reading_event_id"], name: "index_participation_certificates_on_reading_event_id"
    t.index ["user_id"], name: "index_participation_certificates_on_user_id"
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
    t.integer "comments_count", default: 0, null: false
    t.integer "likes_count", default: 0, null: false
    t.index ["category", "created_at"], name: "index_posts_on_category_created"
    t.index ["comments_count", "created_at"], name: "index_posts_comments_count_created"
    t.index ["hidden", "created_at"], name: "index_posts_on_hidden_created"
    t.index ["hidden", "pinned", "created_at"], name: "index_posts_on_status_created"
    t.index ["likes_count", "created_at"], name: "index_posts_likes_count_created"
    t.index ["pinned", "created_at"], name: "index_posts_on_pinned_created"
    t.index ["user_id", "created_at"], name: "index_posts_on_user_created"
    t.index ["user_id", "hidden", "created_at"], name: "index_posts_on_user_hidden_created"
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
    t.string "activity_mode", default: "note_checkin", null: false
    t.boolean "weekend_rest", default: false, null: false
    t.integer "completion_standard", default: 80, null: false
    t.string "fee_type", default: "free", null: false
    t.decimal "fee_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "leader_reward_percentage", precision: 5, scale: 2, default: "20.0", null: false
    t.integer "min_participants", default: 10, null: false
    t.datetime "enrollment_deadline"
    t.datetime "submitted_for_approval_at"
    t.text "approval_reason"
    t.text "approval_notes"
    t.text "rejection_reason"
    t.text "escalation_reason"
    t.datetime "escalated_at"
    t.bigint "escalated_by_user_id"
    t.integer "enrollments_count", default: 0, null: false
    t.integer "check_ins_count", default: 0, null: false
    t.integer "flowers_count", default: 0, null: false
    t.index ["activity_mode"], name: "index_reading_events_on_activity_mode"
    t.index ["approval_status", "created_at"], name: "index_events_on_approval_created"
    t.index ["approval_status", "submitted_for_approval_at"], name: "index_events_approval_status_submitted"
    t.index ["approved_by_id"], name: "index_reading_events_on_approved_by_id"
    t.index ["enrollment_deadline"], name: "index_reading_events_on_enrollment_deadline"
    t.index ["escalated_at"], name: "index_reading_events_on_escalated_at"
    t.index ["escalated_by_user_id"], name: "index_reading_events_on_escalated_by_user_id"
    t.index ["fee_type"], name: "index_reading_events_on_fee_type"
    t.index ["leader_id", "status"], name: "index_events_on_leader_status"
    t.index ["leader_id"], name: "index_reading_events_on_leader_id"
    t.index ["start_date"], name: "index_reading_events_on_start_date"
    t.index ["status", "created_at"], name: "index_events_on_status_created"
    t.index ["status", "start_date"], name: "index_events_status_start_date"
    t.index ["status"], name: "index_reading_events_on_status"
    t.index ["submitted_for_approval_at"], name: "index_reading_events_on_submitted_for_approval_at"
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
    t.index ["reading_event_id", "date"], name: "index_schedules_on_event_date"
    t.index ["reading_event_id", "day_number"], name: "index_reading_schedules_on_reading_event_id_and_day_number", unique: true
    t.index ["reading_event_id"], name: "index_reading_schedules_on_reading_event_id"
  end

  create_table "share_actions", force: :cascade do |t|
    t.string "share_type", null: false
    t.integer "resource_id", null: false
    t.string "platform", null: false
    t.integer "user_id"
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "shared_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform"], name: "index_share_actions_on_platform"
    t.index ["share_type", "platform", "shared_at"], name: "index_share_actions_on_share_type_and_platform_and_shared_at"
    t.index ["share_type", "resource_id"], name: "index_share_actions_on_share_type_and_resource_id"
    t.index ["shared_at"], name: "index_share_actions_on_shared_at"
    t.index ["user_id"], name: "index_share_actions_on_user_id"
  end

  create_table "user_activities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "action_type", null: false
    t.json "details", default: {}, null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type", "created_at"], name: "index_user_activities_on_action_type_and_created_at"
    t.index ["action_type"], name: "index_user_activities_on_action_type"
    t.index ["created_at"], name: "index_user_activities_on_created_at", order: :desc
    t.index ["user_id", "action_type", "created_at"], name: "idx_on_user_id_action_type_created_at_3eb2145f0f"
    t.index ["user_id", "created_at"], name: "index_user_activities_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_activities_on_user_id"
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
    t.integer "posts_count", default: 0, null: false
    t.integer "comments_count", default: 0, null: false
    t.integer "likes_given_count", default: 0, null: false
    t.integer "flowers_given_count", default: 0, null: false
    t.integer "flowers_received_count", default: 0, null: false
    t.index ["flowers_received_count"], name: "index_users_flowers_received"
    t.index ["posts_count"], name: "index_users_posts_count"
    t.index ["role", "created_at"], name: "index_users_on_role_created"
    t.index ["role", "created_at"], name: "index_users_role_created"
    t.index ["role"], name: "index_users_on_role"
    t.index ["wx_openid"], name: "index_users_on_wx_openid", unique: true
    t.index ["wx_unionid"], name: "index_users_on_wx_unionid", unique: true
  end

  add_foreign_key "check_ins", "enrollments"
  add_foreign_key "check_ins", "reading_schedules"
  add_foreign_key "check_ins", "users"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "content_reports", "check_ins"
  add_foreign_key "content_reports", "users"
  add_foreign_key "content_reports", "users", column: "admin_id"
  add_foreign_key "daily_flower_stats", "reading_events"
  add_foreign_key "daily_leadings", "reading_schedules"
  add_foreign_key "daily_leadings", "users", column: "leader_id"
  add_foreign_key "enrollments", "reading_events"
  add_foreign_key "enrollments", "users"
  add_foreign_key "event_enrollments", "reading_events"
  add_foreign_key "event_enrollments", "users"
  add_foreign_key "flower_certificates", "reading_events"
  add_foreign_key "flower_certificates", "users"
  add_foreign_key "flower_quotas", "reading_events"
  add_foreign_key "flower_quotas", "users"
  add_foreign_key "flowers", "check_ins"
  add_foreign_key "flowers", "reading_schedules"
  add_foreign_key "flowers", "users", column: "giver_id"
  add_foreign_key "flowers", "users", column: "recipient_id"
  add_foreign_key "likes", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "participation_certificates", "reading_events"
  add_foreign_key "participation_certificates", "users"
  add_foreign_key "posts", "users"
  add_foreign_key "reading_events", "users", column: "approved_by_id"
  add_foreign_key "reading_events", "users", column: "escalated_by_user_id"
  add_foreign_key "reading_events", "users", column: "leader_id"
  add_foreign_key "reading_schedules", "reading_events"
  add_foreign_key "reading_schedules", "users", column: "daily_leader_id"
  add_foreign_key "user_activities", "users"
end

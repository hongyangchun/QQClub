# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    nickname { Faker::Name.name }
    wx_openid { "test_openid_#{SecureRandom.hex(8)}" }
    role { 0 }  # user role
  end

  factory :admin, class: "User" do
    nickname { Faker::Name.name }
    wx_openid { "admin_openid_#{SecureRandom.hex(8)}" }
    role { 1 }  # admin role
  end

  factory :root, class: "User" do
    nickname { "Root Admin" }
    wx_openid { "root_openid_#{SecureRandom.hex(8)}" }
    role { 2 }  # root role
  end

  factory :group_leader, class: "User" do
    nickname { Faker::Name.name }
    wx_openid { "leader_openid_#{SecureRandom.hex(8)}" }
    role { 0 }  # user role
  end

  factory :daily_leader, class: "User" do
    nickname { Faker::Name.name }
    wx_openid { "daily_openid_#{SecureRandom.hex(8)}" }
    role { 0 }  # user role
  end
end
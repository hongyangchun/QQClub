# frozen_string_literal: true

FactoryBot.define do
  factory :reading_schedule do
    association :reading_event
    day_number { 1 }
    reading_progress { "第1章：介绍" }
    date { Date.today }
    association :daily_leader, factory: :user, optional: true

    trait :with_leader do
      association :daily_leader, factory: :user
    end

    trait :today do
      date { Date.today }
    end

    trait :past do
      date { Date.yesterday }
    end

    trait :future do
      date { Date.tomorrow }
    end
  end
end
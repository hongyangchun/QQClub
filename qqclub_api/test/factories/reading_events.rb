# frozen_string_literal: true

FactoryBot.define do
  factory :reading_event do
    title { Faker::Book.title }
    book_name { Faker::Book.author }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    start_date { Date.today }
    end_date { Date.today + 30.days }
    max_participants { 20 }
    enrollment_fee { 100.0 }
    status { :draft }
    approval_status { :pending }
    leader_assignment_type { :voluntary }
    association :leader, factory: :user

    # 自动创建阅读计划
    after(:create) do |event|
      # 创建默认的阅读计划
      (1..3).each do |day|
        event.reading_schedules.create!(
          day_number: day,
          reading_progress: "第#{day}章：测试章节内容",
          date: event.start_date + (day - 1).days
        )
      end
    end

    trait :approved do
      approval_status { :approved }
    end

    trait :active do
      status { :in_progress }
      start_date { Date.today - 1.week }
      end_date { Date.today + 2.weeks }
      approval_status { :approved }
    end

    trait :completed do
      status { :completed }
      start_date { Date.today - 2.months }
      end_date { Date.today - 1.month }
      approval_status { :approved }
    end
  end
end
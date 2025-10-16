# frozen_string_literal: true

FactoryBot.define do
  factory :check_in do
    content { Faker::Lorem.paragraph(sentence_count: 5) }
    association :user
    association :reading_schedule
  end
end
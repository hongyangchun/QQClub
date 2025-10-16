# frozen_string_literal: true

FactoryBot.define do
  factory :flower do
    comment { Faker::Lorem.sentence(word_count: 5) }
    association :giver, factory: :user
    association :receiver, factory: :user
    association :check_in
  end
end
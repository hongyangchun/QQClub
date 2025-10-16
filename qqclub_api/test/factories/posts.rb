# frozen_string_literal: true

FactoryBot.define do
  factory :post do
    title { Faker::Lorem.sentence(word_count: 3) }
    content { Faker::Lorem.paragraph(sentence_count: 5) }
    pinned { false }
    hidden { false }
    association :user

    trait :pinned do
      pinned { true }
    end

    trait :hidden do
      hidden { true }
    end
  end
end
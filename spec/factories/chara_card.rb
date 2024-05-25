# frozen_string_literal: true

FactoryBot.define do
  factory :chara_card, class: 'Unlight::CharaCard' do
    name { Faker::Name.name }
  end
end

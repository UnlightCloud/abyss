# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_card, class: 'Unlight::WeaponCard' do
    name { Faker::Name.name }
  end
end

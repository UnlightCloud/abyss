# frozen_string_literal: true

FactoryBot.define do
  factory :achievement_inventory, class: 'Unlight::AchievementInventory' do
    avatar
    achievement
  end
end

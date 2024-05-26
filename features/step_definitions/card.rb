# frozen_string_literal: true

Given('the following character cards') do |table|
  table.hashes.each do |character_card|
    create(:chara_card, character_card)
  end
end

Given('the following weapon cards') do |table|
  table.hashes.each do |weapon_card|
    create(:weapon_card, weapon_card)
  end
end

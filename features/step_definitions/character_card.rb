# frozen_string_literal: true

Given('the following character cards') do |table|
  table.hashes.each do |character_card|
    create(:chara_card, character_card)
  end
end

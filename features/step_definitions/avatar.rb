# frozen_string_literal: true

Given('the following avatars') do |table|
  table.hashes.each do |avatar|
    player = Unlight::Player[name: avatar.delete('player_name')]
    create(:avatar, avatar.merge(player:))
  end
end

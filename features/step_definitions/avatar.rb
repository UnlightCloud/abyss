# frozen_string_literal: true

Given('the following avatars') do |table|
  table.hashes.each do |avatar|
    player = Unlight::Player[name: avatar.delete('player_name')]
    create(:avatar, avatar.merge(player:))
  end
end

Given('the following avatar parts') do |table|
  table.hashes.each do |avatar_part|
    create(:avatar_part, avatar_part)
  end
end

Given('the following avatar part grants') do |table|
  table.hashes.each do |grants|
    avatar = Unlight::Avatar[name: grants.delete('avatar_name')]
    avatar.get_part(grants.delete('avatar_part_id'))
  end
end

Given('the following avatar items') do |table|
  table.hashes.each do |avatar_item|
    create(:avatar_item, avatar_item)
  end
end

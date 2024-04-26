# frozen_string_literal: true

Given('the following players') do |table|
  table.hashes.each do |player|
    player['salt'] ||= Faker::Crypto.sha1

    Unlight::Player.create(player)
  end
end

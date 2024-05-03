# frozen_string_literal: true

Given('the following players') do |table|
  table.hashes.each do |player|
    create(:player, player)
  end
end

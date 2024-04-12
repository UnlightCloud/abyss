# frozen_string_literal: true

namespace :data do
  desc 'Generate game data for client'
  task generate_client_data: :environment do
    Unlight::DB.logger = nil

    Abyss.app.resolve('services.client_data_exporter').call do |dataset|
      puts "Generating #{dataset.table_name}.csv"
    end
  end
end

# frozen_string_literal: true

namespace :data do
  desc 'Generate game data for client'
  task generate_client_data: :environment do
    Unlight::DB.logger = nil

    path = Pathname.new('tmp/export')
    command = Unlight::Container['exporter.export_command']

    command.execute(path:) do |dataset|
      puts "Generating #{dataset.table_name}.csv"
    end
  end
end

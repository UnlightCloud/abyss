# frozen_string_literal: true

module Abyss
  # :nodoc:
  module Commands
    # Upgrade the database schema and reload the game data
    #
    # @since 0.1.0
    class Upgrade < Dry::CLI::Command
      desc 'Upgrade the database schema and reload the game data'

      option :version, type: :string, desc: 'The schema version to upgrade to'
      option :import, type: :boolean, default: true, desc: 'Import game data after upgrading'
      option :cpu_decks, type: :boolean, default: true, desc: 'Initialize CPU decks after upgrading'

      def call(**options)
        require 'dawn/database'

        Dawn::Database.migrate!(options.fetch(:version, nil))
        import_data if options[:import]
        initialize_cpu_decks if options[:cpu_decks]
      end

      private

      def import_data
        require Abyss.root.join('src', 'unlight')
        require 'dawn/services/data_importer'

        importer = Dawn::DataImporter.new
        importer.import do |dataset|
          puts "Importing #{dataset.model_name}"
        end
      end

      def initialize_cpu_decks
        require Abyss.root.join('src', 'unlight')

        Unlight::CharaCardDeck.initialize_CPU_deck
      end
    end

    register 'upgrade', Upgrade, aliases: ['u']

    before('upgrade') { Abyss::Maintenance.enable }
    after('upgrade') { Abyss::Maintenance.disable }
  end
end

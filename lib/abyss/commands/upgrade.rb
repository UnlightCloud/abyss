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
        require 'abyss/prepare'

        Abyss::Migrator.new(Abyss.app[:settings][:database_url]).migrate!
        import_data if options[:import]
        initialize_cpu_decks if options[:cpu_decks]
      end

      private

      def import_data
        require 'csv'
        require Abyss.root.join('src', 'unlight')
        Abyss.boot

        command = Abyss.app.resolve('importer.import_command')
        command.execute(data) do |repository, data|
          puts "#{repository} imported #{data.count} records"
        end
      end

      def initialize_cpu_decks
        require Abyss.root.join('src', 'unlight')
        Abyss.boot

        Unlight::CharaCardDeck.initialize_CPU_deck
      end

      def data
        @data ||=
          sources.to_h do |source|
            name = source.basename.to_s[/([a-zA-Z0-9]+)\.csv/, 1]
            [name, CSV.read(source, headers: true)]
          end
      end

      def sources
        @sources ||=
          Abyss.root.glob('data/csv/{ja,tcn}/*.csv')
      end
    end

    register 'upgrade', Upgrade, aliases: ['u']

    before('upgrade') { Abyss::Maintenance.enable }
    after('upgrade') { Abyss::Maintenance.disable }
    after('upgrade') { Abyss::Cache.flush }
  end
end

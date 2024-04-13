# frozen_string_literal: true

require 'sequel'

module Abyss
  # The migrator to manage the database migration
  #
  # @since 0.1.0
  class Migrator
    # Database connection configuration
    #
    # @return [String] the database connection string
    #
    # @since 0.1.0
    attr_reader :config

    # Initialize the migrator
    #
    # @param config [String] the database connection string
    #
    # @since 0.1.0
    def initialize(config, migrations_path = 'db/migrations')
      @config = config
      @migrations_path = migrations_path
    end

    # Migrate database to specify version
    #
    # @param version [Integer] the version to migrate
    #
    # @since 0.1.0
    def migrate!(target = nil)
      run do |database|
        Sequel::Migrator.run(database, migrations_path, target:, use_advisory_lock: true)
      end
    end

    # Check if there is any pending migration
    #
    # @param version [Integer] the version to check
    #
    # @return [Boolean] true if there is any pending migration
    #
    # @since 0.1.0
    def pending?(target = nil)
      run do |database|
        Sequel::Migrator.is_current?(database, migrations_path, target:, use_advisory_lock: true) == false
      end
    end

    # Return migration path
    #
    # @return [String] the migration path
    #
    # @since 0.1.0
    def migrations_path
      Abyss.root.join(@migrations_path)
    end

    # Run with the database connection
    #
    # @block [database] the database connection
    #
    # @since 0.1.0
    def run(&)
      Sequel.extension :migration
      Sequel.connect(config, &)
    end
  end
end

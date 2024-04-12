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
    def initialize(config)
      @config = config
    end

    # Migrate database to specify version
    #
    # @param version [Integer] the version to migrate
    #
    # @since 0.1.0
    def migrate!(version = nil)
      run do |database|
        Sequel::Migrator.run(database, Abyss.root.join('db/migrations'), target: version, use_advisory_lock: true)
      end
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

# Unlight
# Copyright (c) 2019 Open Unlight
# This software is released under the Apache 2.0 License.
# https://opensource.org/licenses/Apache2.0

# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'singleton'
require 'forwardable'

require 'sequel'

require 'dawn'

module Dawn
  # Database
  #
  # Manage the database connection from config or environment to improve deployment
  #
  # @since 0.1.0
  class Database
    class << self
      extend Forwardable

      delegate %w[migrate! pending? config current] => :instance
    end

    include Singleton

    attr_reader :config_file

    # @since 0.1.0
    def initialize
      # TODO: Add config manager
      @config_file = Dawn.root.join('config/database.yml')
      @mutex = Mutex.new
    end

    # @return [Hash] the database config
    #
    # @since 0.1.0
    def config
      return @config if @config

      @config = ENV.fetch('DATABASE_URL', nil)
      return @config unless @config.nil? && config_file.exist?

      template = ERB.new(config_file.read)
      @config ||=
        YAML.safe_load(template.result(binding), aliases: true).fetch(Dawn.env, nil)
      @config
    end

    # Migrate database to specify version
    #
    # @since 0.1.0
    def migrate!(version = nil)
      Sequel.extension :migration
      version = version.to_i unless version.nil?
      current do |database|
        Sequel::Migrator.run(database, Dawn.root.join('db/migrations'), target: version, use_advisory_lock: true)
      end
    end

    # Check any pendign migrations
    #
    # @since 0.1.0
    #
    # @return [Boolean] true if there are pending migrations
    def pending?(version = nil)
      Sequel.extension :migration
      version = version&.to_i unless version.nil?
      current do |database|
        Sequel::Migrator.is_current?(database, Dawn.root.join('db/migrations'), target: version, use_advisory_lock: true) == false
      end
    end

    # @return [Sequel] the current database object
    #
    # @since 0.1.0
    def current(&)
      return @current if @current

      @mutex.synchronize do
        return @current if @current

        @current = Sequel.connect(config, logger: SemanticLogger['Database'], &)
      end

      @current
    end
  end
end

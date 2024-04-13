# frozen_string_literal: true

module Unlight
  module Importer
    # The dataset for specific table
    #
    # @since 0.1.0
    class Dataset
      include Enumerable

      # Supported languages
      #
      # @since 0.1.0
      LANGUAGE_SET = /(_tcn|_en|_scn|_kr|_fr|_ina|_thai)$/

      # @api private
      attr_reader :schema, :language

      # @api private
      def initialize(schema = language = 'tcn')
        @schema = schema
        @language = language.to_s
        @items = []
      end

      # @api private
      def add_entry(item)
        @items << parse(item)
      end

      # @api private
      def each(&)
        @items.each(&)
      end

      private

      # @return [Hash] the parsed item
      #
      # @api private
      def parse(item)
        item.then { |row| localize_columns(row) }
            .then { |row| parse_datetime(row) }
            .then { |row| refresh_updated_at(row) }
            .then { |row| fill_empty(row) }
      end

      # @return [Hash] the localized columns
      #
      # @api private
      def localize_columns(row)
        row.filter_map do |key, value|
          next [key, value] unless key.match?(LANGUAGE_SET)
          next unless key.end_with?("_#{language}")

          [key.sub(/_#{language}$/, ''), value]
        end.to_h
      end

      # @return [Hash] the parsed datetime columns
      #
      # @api private
      def parse_datetime(row)
        row.to_h do |key, value|
          next [key, value] if value.nil?
          next [key, value] unless key.end_with?('_at')

          [key, DateTime.parse(value)]
        end
      end

      # @return [Hash] the updated row
      #
      # @api private
      def refresh_updated_at(row)
        row['updated_at'] = Time.now
        row
      end

      # @return [Hash] the filled empty data
      #
      # @api private
      def fill_empty(row)
        row.to_h do |key, value|
          next [key, value] if key.end_with?('_at')
          next [key, ''] if schema[key.to_sym][:type] == :string && value.nil?

          [key, value]
        end.to_h
      end
    end
  end
end

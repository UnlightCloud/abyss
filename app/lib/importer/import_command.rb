# frozen_string_literal: true

module Unlight
  module Importer
    # Import command
    class ImportCommand
      include Deps[:inflector]

      # @api private
      def call(data, batch_size: 1000)
        data.each do |name, rows|
          repository = find_repository(name)
          dataset = build_dataset(repository.db_schema, rows)

          repository.truncate
          dataset.each_slice(batch_size) do |batch|
            repository.multi_insert(batch)
            yield repository, batch if block_given?
          end
        end
      end

      private

      def build_dataset(schema, rows)
        Dataset.new(schema).tap do |dataset|
          rows.each { |row| dataset.add_entry(row) }
        end
      end

      def find_repository(name)
        # NOTE: after model is register as component use container to resolve
        inflector.constantize("Unlight::#{inflector.singularize(name)}")
      end
    end
  end
end

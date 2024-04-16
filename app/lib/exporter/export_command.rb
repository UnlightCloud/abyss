# frozen_string_literal: true

require 'csv'

module Unlight
  module Exporter
    # Client data exporter
    #
    # @since 0.1.0
    class ExportCommand
      include Deps[:inflector]

      # @since 0.1.0
      MODELS = %w[
        CharaCard
        ActionCard
        WeaponCard
        Feat
        PassiveSkill
        AvatarItem
        EventCard
        Quest
        QuestLand
        QuestMap
        RareCardLot
        RealMoneyItem
        AvatarPart
        Shop
        Achievement
        ProfoundData
        ProfoundTreasureData
        Charactor
      ].freeze

      def execute(path: nil)
        path = Pathname.new(path)
        ensure_export_path(path)

        datasets.each do |dataset|
          yield dataset if block_given?

          CSV.open(path.join("#{dataset.table_name}.csv"), 'w') do |csv|
            dataset.each { |row| csv << row.to_client }
          end
        end
      end

      private

      def ensure_export_path(path)
        path.mkpath unless path.exist?
      end

      def datasets
        @datasets = MODELS.map { |model| inflector.constantize("Unlight::#{model}") }
      end
    end
  end
end

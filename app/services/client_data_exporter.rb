# frozen_string_literal: true

require 'csv'
require 'sequel'
require 'sequel/extensions/inflector'

module Unlight
  module Services
    # :nodoc:
    class ClientDataExporter
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

      EXPORT_PATH = Abyss.root.join('tmp/export')

      def call
        ensure_export_path

        datasets.each do |dataset|
          yield dataset if block_given?

          CSV.open(EXPORT_PATH.join("#{dataset.table_name}.csv"), 'w') do |csv|
            dataset.each { |row| csv << row.to_client }
          end
        end
      end

      private

      def ensure_export_path
        EXPORT_PATH.mkpath unless EXPORT_PATH.exist?
      end

      def datasets
        @datasets = MODELS.map { |model| Unlight.const_get(model) }
      end
    end
  end
end

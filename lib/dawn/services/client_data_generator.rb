# frozen_string_literal: true

require 'date'
require 'csv'
# NOTE: Add String#singularize support
require 'sequel'
require 'sequel/extensions/inflector'

require 'dawn'
require 'dawn/dataset'

module Dawn
  # Export Game Data for Client
  #
  # @since 0.1.0
  class ClientDataGenerator
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

    # @param block [Proc] the callback when rows imported
    #
    # @since 0.1.0
    def export
      destination.mkpath unless destination.exist?

      datasets.each do |dataset|
        yield dataset if block_given?

        CSV.open(destination.join("#{dataset.table_name}.csv"), 'w') do |csv|
          dataset.each { |row| csv << row.to_client }
        end
      end
    end

    # @return [Pathname] the export data destination
    #
    # @since 0.1.0
    def destination
      @destination ||= Dawn.root.join('tmp/export')
    end

    # @return [Array<Sequel::Dataset>] the models to export
    #
    # @since 0.1.0
    def datasets
      @datasets = MODELS.map { |name| Unlight.const_get(name) }
    end
  end
end

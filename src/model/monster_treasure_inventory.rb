# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # パーツのインベントリクラス
  class MonsterTreasureInventory < Sequel::Model
    # 他クラスのアソシエーション
    many_to_one :cpu_card_data # アバターを持つ
    many_to_one :treasure_data # アバターパーツを持つ

    plugin :validation_class_methods
    plugin :hook_class_methods

    # インサート時の前処理
    before_create do
      self.created_at = Time.now.utc
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
    end

    SLOTS2REWARD = [Unlight::Reward::WEAPON_CARD, 0, Unlight::Reward::EVENT_CARD]

    def get_treasure
      ret = { step: 0, item: [0, 0, 0] }
      t = treasure_data
      if t
        case t.treasure_type
        when TG_CHARA_CARD
          ret = { step:, item: [Unlight::Reward::RANDOM_CARD, t.value, num] }
        when TG_SLOT_CARD
          ret = { step:, item: [SLOTS2REWARD[t.slot_type], t.value, num] } unless (SLOTS2REWARD[t.slot_type]).zero?
        when TG_AVATAR_ITEM
          ret = { step:, item: [Unlight::Reward::ITEM, t.value, num] }
        end
      end
      ret
    end
  end
end

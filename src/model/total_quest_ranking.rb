# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # 課金アイテムクラス
  class TotalQuestRanking < Sequel::Model
    many_to_one :avatar # プレイヤーに複数所持される

    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods
    # キャッシュをON
    plugin :caching, CACHE, ignore_exceptions: true

    # バリデーションの設定
    Sequel::Model.plugin :validation_class_methods

    # インサート時の前処理
    before_create do
      self.created_at = Time.now.utc
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
    end

    def self.ranking_data
      TotalQuestRanking
    end

    def self.ranking_data_count(server_type)
      TotalQuestRanking.filter(server_type:).count
    end

    def self.data_type
      'quest'
    end

    extend TotalRanking

    # 指定したアバターのランキングを取得する
    def self.get_ranking(a_id, server_type, point = 0)
      index = get_order_ranking_id(server_type).index(a_id)
      lr = last_ranking(server_type)
      # 100番より値が低くて
      if lr >= point && point.positive?
        ret = { rank: EstimationRanking.get_ranking(RANK_TYPE_TQ, server_type, point), arrow: RANK_NONE, point: }
      elsif index && index < 100
        ret = { rank: index + 1, arrow: get_arrow_set(server_type)[index], point: }
      else
        ret = { rank: EstimationRanking.get_ranking(RANK_TYPE_TQ, server_type, point), arrow: RANK_NONE, point: }
      end
      ret
    end

    # ポイントをもったすべてのアバターを取る(ソート済みのアバターとポイントのArrayを返す)
    def self.point_avatars(server_type)
      avatars = {}
      # 現在から一月アップデートされたことのあるアバターが対象
      last_update = Date.today - 30
      st = Time.utc(last_update.year, last_update.month, last_update.day)
      Avatar.filter(server_type:).filter { updated_at > st }.all do |a|
        if a.quest_point
          avatars[a.id] = a.quest_point
        end
      end
      avatars.to_a.sort { |a, b| b[1] <=> a[1] }
    end

    initialize_ranking
  end
end

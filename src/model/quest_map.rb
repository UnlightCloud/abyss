# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # クエストのマップクラス
  class QuestMap < Sequel::Model
    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods
    plugin :caching, CACHE, ignore_exceptions: true

    # 他クラスのアソシエーション
    one_to_many :quests # 複数のクエストデータを保持

    # 全体データバージョンを返す
    def self.data_version
      ret = cache_store.get('QuestMapVersion')
      unless ret
        ret = refresh_data_version
        cache_store.set('QuestMapVersion', ret)
      end
      ret
    end

    # 全体データバージョンを更新（管理ツールが使う）
    def self.refresh_data_version
      m = QuestMap.order(:updated_at).last
      if m
        cache_store.set('QuestMapVersion', m.version)
        m.version
      else
        0
      end
    end

    # バージョン情報(３ヶ月で循環するのでそれ以上クライアント側で保持してはいけない)
    def version
      updated_at.to_i % MODEL_CACHE_INT
    end

    # インサート時の前処理
    before_create do
      self.created_at = Time.now.utc
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
    end

    # ランダムにクエストのIDを1つ返す(クリアNumがマップの難易度を超えていたらボスが出るのを許す)
    def get_quest_id(clear_num = 0, time = 0, cleared_map = false)
      SERVER_LOG.info("<UID:>QuestServer: [#{__method__}] clear_num:#{clear_num},time:#{time},cleard:#{cleared_map}")
      r = QuestMap.get_realty(time)
      s = 0
      boss = (clear_num >= difficulty) || cleared_map
      until s.positive?
        q = Quest.get_map_in_reality(id, r, boss)
        s = q.count if q
        r -= 1
        break if r.zero?
      end
      ret = q[rand(q.count)] if q
      SERVER_LOG.info("<UID:>QuestServer: [#{__method__}] ret:#{ret}")
      if ret
        ret.id
      else
        1
      end
    end

    # ランダムにボスクエストのIDを1つ返す
    def get_boss_quest_id
      q = Quest.get_map_in_boss(id)
      ret = q[rand(q.count)] unless q.empty?
      if ret
        ret.id
      else
        1
      end
    end

    # クエストが進行度MAXか？
    def get_clear_capacity(clear_num)
      difficulty <= clear_num
    end

    # レアリティを決定する
    def self.get_realty(time = 0)
      r = rand(MAP_REALITY_NUM)
      ret = 1
      if MAP_REALITY[time]
        MAP_REALITY[time].each_index do |i|
          if MAP_REALITY[time][i] > r
            ret = i + 1
          else
            break
          end
        end
      end

      ret
    end

    # 特定地域のマップIDリストをもらえる
    def self.get_quest_map_list(reg)
      ret = cache_store.get("region:#{reg}")
      unless ret
        ret = QuestMap.filter({ region: reg }).all.map(&:id)
        cache_store.set("region:#{reg}", ret)
      end
      ret
    end

    # 特定地域のキャッシュをクリア
    def self.refresh_cache(reg)
      cache_store.delete("region:#{reg}")
    end

    def to_client
      [id, name, caption, region, level, ap, difficulty]
    end
  end
end

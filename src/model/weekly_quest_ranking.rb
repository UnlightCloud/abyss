# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # 課金アイテムクラス
  class WeeklyQuestRanking < Sequel::Model
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

    # 指定したアバターのランキングを取得する
    def self.get_ranking(a_id, server_type, cache = true)
      if cache
        ret = cache_store.get("weekly_quest_ranking:#{a_id}_#{server_type}")
      end
      unless ret
        ret = WeeklyQuestRanking.filter([[:avatar_id, a_id], [:server_type, server_type]]).all.first
        cache_store.set("weekly_quest_ranking:#{a_id}_#{server_type}", ret)
      end
      if ret
        ret = { rank: ret.id, arrow: ret.arrow, point: ret.point }
      else
        ret = { rank: 0, arrow: 0, point: 0 }
      end
      ret
    end

    # ソート済みのランキングを取得する
    def self.get_order_ranking(server_type, st_i = 0, end_i = 99)
      ret = cache_store.get("weekly_quest_ranking:all_#{server_type}")
      unless ret
        ret = WeeklyQuestRanking.filter(server_type:).filter { id <= 100 }.all
        cache_store.set("weekly_quest_ranking:all_#{server_type}", ret, RANK_CACHE_TTL)
        cache_store.set("weekly_quest_ranking:all_id_#{server_type}", ret.map(&:avatar_id), RANK_CACHE_TTL)
        cache_store.set("weekly_quest_ranking:arrow_#{server_type}", ret.map(&:arrow), RANK_CACHE_TTL)
      end
      ret[st_i..end_i]
    end

    def self.create_arrow(old_id_set, id, i)
      # 前回の記録があるならばARROWを作る
      ret = RANK_S_UP
      if old_id_set
        rid = id
        old_rank = old_id_set.index(rid)
        if old_rank.nil?
          ret = RANK_S_UP
        elsif old_rank == i
          ret = RANK_NONE
        elsif old_rank > i
          if old_rank - i >= RANK_SUPER_DIFF
            ret = RANK_S_UP
          else
            ret = RANK_UP
          end
        elsif old_rank < i
          if i - old_rank >= RANK_SUPER_DIFF
            ret = RANK_S_DOWN
          else
            ret = RANK_DOWN
          end
        else
          ret = RANK_NONE
        end
      end
      ret
    end

    def self.get_order_ranking_id(server_type)
      ret = cache_store.get("weekly_quest_ranking:all_id_#{server_type}")
      unless ret
        ret = WeeklyQuestRanking.filter(server_type:).filter(Sequel.cast_string(:id) <= 100).map(&:avatar_id)
        cache_store.set("weekly_quest_ranking:all_id_#{server_type}", ret, RANK_CACHE_TTL)
      end
      ret
    end

    # TODO: Create service object to calculate ranking
    # 指定したアバターのランキングを更新する(外部でかつslaveから更新せよ)
    def self.update_ranking(server_type)
      before_rank_id_set = get_order_ranking_id(server_type)
      avatars = {}
      ranking = []
      sunday = Date.today - Date.today.wday
      st = Time.utc(sunday.year, sunday.month, sunday.day)
      QuestClearLog.filter(server_type:).filter { updated_at > st }.all do |log|
        if log.avatar_id
          avatars[log.avatar_id] = 0 unless avatars[log.avatar_id]
          avatars[log.avatar_id] += log.quest_point
        end
      end
      ranking = avatars.to_a.sort { |a, b| b[1] <=> a[1] }
      weekly_ranking = WeeklyQuestRanking.filter(server_type:).order(Sequel.asc(:id)).all
      (0..99).each do |i|
        if ranking[i]
          if weekly_ranking[i]
            w = weekly_ranking[i]
            w.avatar_id = ranking[i][0]
            w.name = Avatar[ranking[i][0]].name if Avatar[ranking[i][0]]

            w.point = ranking[i][1]
            w.arrow = create_arrow(before_rank_id_set, w.avatar_id, i)
            w.server_type = server_type
            w.save_changes
          else
            WeeklyQuestRanking.new do |rank|
              rank.avatar_id = ranking[i][0]
              rank.name = Avatar[ranking[i][0]].name if Avatar[ranking[i][0]]
              rank.point = ranking[i][1]
              rank.arrow = create_arrow(before_rank_id_set, rank.avatar_id, i)
              rank.server_type = server_type
              rank.save_changes
            end
          end
        else
          if weekly_ranking[i]
            w = weekly_ranking[i]
            w.avatar_id = 0
            w.name = ''
            w.point = 0
            w.arrow = 0
            w.save_changes
          else
            WeeklyQuestRanking.new do |rank|
              rank.avatar_id = 0
              rank.name = ''
              rank.point = 0
              rank.arrow = 0
              rank.server_type = server_type
              rank.save_changes
            end
          end

        end
      end

      # 圏外をゆっくり保存する
      lst = ranking.size - 1 > RANK_OUT_LIMIT ? RANK_OUT_LIMIT : ranking.size - 1
      if ranking[100..lst]
        ranking[100..lst].each_index do |i|
          if weekly_ranking[i + 100]
            w = weekly_ranking[i + 100]
            w.avatar_id = ranking[i + 100][0]
            w.point = ranking[i + 100][1]
            w.save_changes
          else
            WeeklyQuestRanking.new do |rank|
              rank.avatar_id = ranking[i + 100][0]
              rank.point = ranking[i + 100][1]
              rank.server_type = server_type
              rank.save_changes
            end
          end
          sleep RANK_OUT_SLEEP
        end
      end
      cache_store.delete("weekly_quest_ranking:all_#{server_type}")
      cache_store.delete("weekly_quest_ranking:all_id_#{server_type}")
    end

    # 圏外のアバターも更新する（重たいのでたまに）
    # ポイントをもったすべてのアバターを取る(ソート済みのアバターとポイントのArrayを返す)
    def self.point_avatars(server_type)
      avatars = {}
      sunday = Date.today - Date.today.wday
      st = Time.utc(sunday.year, sunday.month, sunday.day)
      MatchLog.filter(server_type:).filter { finish_at > st }.all do |log|
        if log.winner_avatar_id
          avatars[log.winner_avatar_id] = 0 unless avatars[log.winner_avatar_id]
          avatars[log.winner_avatar_id] += log.quest_point
        end
      end
      avatars.to_a.sort { |a, b| b[1] <=> a[1] } # これをどっか軽量なところに保存したいが・・・・。
    end

    # 100位のポイントを返す
    def self.last_ranking(server_type)
      weekly_ranking = WeeklyQuestRanking.filter(server_type:).order(Sequel.asc(:id)).all
      weekly_ranking[100].point
    end

    # ランキングを文字列で返す（キャッシュつき）
    def self.get_ranking_str(server_type, st_i = 0, end_i = 99)
      ret = cache_store.get("weekly_quest_ranking:#{st_i}_#{end_i}_#{server_type}_str")
      unless  ret
        set = WeeklyQuestRanking.get_order_ranking(server_type, st_i, end_i)
        ret = []
        if set
          set.each do |s|
            SERVER_LOG.info("DataServer: [#{__method__}] name:#{s.name} arrow:#{s.arrow} point:#{s.point}")
            ret << s.name
            ret << s.arrow
            ret << s.point
          end
        end
        ret = ret.join(',')
        cache_store.set("weekly_quest_ranking:#{st_i}_#{end_i}_#{server_type}_str", ret, RANK_CACHE_TTL)
      end
      ret
    end
  end
end

# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # 課金アイテムクラス
  class TotalCharaVoteRanking < Sequel::Model
    many_to_one :avatar # プレイヤーに複数所持される

    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods
    # キャッシュをON
    plugin :caching, CACHE, ignore_exceptions: true, ttl: 1200 # 10分だけキャッシュする･･･

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
      TotalCharaVoteRanking
    end

    def self.ranking_data_count(server_type)
      TotalCharaVoteRanking.filter(server_type:).count
    end

    def self.data_type
      'chara_vote'
    end

    extend TotalRanking

    # 指定したキャラのランキングを取得する
    def self.get_ranking(i_id, server_type, point = 0)
      index = get_order_ranking_item_id(server_type).index(i_id)
      if index
        ret = { rank: index + 1, arrow: get_arrow_set(server_type)[index], point: }
      end
      ret
    end

    def self.start_up(server_type)
      list = ItemInventory.filter((Sequel.cast_string(:avatar_item_id) >= CHARA_VOTE_ITEM_START_ID) & (Sequel.cast_string(:avatar_item_id) <= CHARA_VOTE_ITEM_END_ID)).filter(server_type:).order(Sequel.asc(:avatar_item_id)).all
      set_hash = Hash.new(0)
      list.each do |i|
        set_hash[i.avatar_item_id] += 1
      end
      chara_names = {}
      set_hash.each do |key, value|
        item = AvatarItem[key]
        charactor_id = item.id - CHARA_VOTE_ITEM_START_ID + 1
        chara_names[charactor_id] = Charactor[charactor_id].name unless chara_names[charactor_id]
        TotalCharaVoteRanking.update_vote_ranking(key, chara_names[charactor_id], value)
      end
    end

    def self.create_arrow_item_id(server_type)
      # 前回の記録があるならばARROWを作る
      before = CACHE.get("#{@ranking_all_id_before}_#{server_type}")
      if before
        arrow_set = []
        a_id_set = CACHE.get("#{@ranking_all_id}_#{server_type}")
        a_id_set ||= ranking_data.filter(server_type:).order(Sequel.desc(:point)).limit(RANKING_COUNT_NUM).all.map(&:avatar_item_id)
        a_id_set.each_index do |i|
          rid = a_id_set[i]
          old_rank = before.index(rid)
          if old_rank.nil?
            arrow_set << RANK_S_UP
          elsif old_rank == i
            arrow_set << RANK_NONE
          elsif old_rank > i
            if (old_rank - i) >= RANK_SUPER_DIFF
              arrow_set << RANK_S_UP
            else
              arrow_set << RANK_UP
            end
          elsif old_rank < i
            if i - old_rank >= RANK_SUPER_DIFF
              arrow_set << RANK_S_DOWN
            else
              arrow_set << RANK_DOWN
            end
          else
            arrow_set << RANK_NONE
          end
        end
        CACHE.set("#{@ranking_arrow}_#{server_type}", arrow_set, RANK_CACHE_TTL)
      else
        CACHE.set("#{@ranking_arrow}_#{server_type}", [], RANK_CACHE_TTL)
      end
    end

    def self.get_order_ranking_item_id(server_type)
      ret = CACHE.get("#{@ranking_all_id}_#{server_type}")
      unless ret
        ret = ranking_data.filter(server_type:).order(Sequel.desc(:point)).limit(RANKING_COUNT_NUM).all.map(&:avatar_item_id)
        CACHE.set("#{@ranking_all_id}_#{server_type}", ret, RANK_CACHE_TTL)
        create_arrow_item_id(server_type)
      end
      ret
    end

    def self.update_vote_ranking(item_id, name, point, server_type)
      lr = last_ranking(server_type)
      r = ranking_data.filter(server_type:).filter(avatar_item_id: item_id).all.first
      if lr < point
        # すでに登録済みな
        if r
        # 新規なら
        elsif lr.zero?
          r = ranking_data.new
        else
          # いっぱいならケツと交換
          r = ranking_data.filter(server_type:).order(Sequel.desc(:point)).limit(RANKING_COUNT_NUM).all.last
        end
        r.avatar_item_id = item_id
        r.name = name
        r.point = point
        r.server_type = server_type
        r.save_changes
        all_cache_delete
      elsif r # すでにあるものがランキング外に落ちるときはポイントをいれるだけ
        r.point = point
        r.server_type = server_type
        r.save_changes
        all_cache_delete
      end
      ranking_data.get_ranking(item_id, server_type, point)
    end

    initialize_ranking
  end
end

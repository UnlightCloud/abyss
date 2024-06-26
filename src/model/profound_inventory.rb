# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # 渦のインベントリクラス
  class ProfoundInventory < Sequel::Model
    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods

    # 他クラスのアソシエーション
    many_to_one :profound, class: Unlight::Profound, key: :profound_id # 渦情報を保持

    # インサート時の前処理
    before_create do
      self.created_at = Time.now.utc
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
    end

    # 表示するランキングリストの数
    FIN_VIEW_RANKING_NUM = 100

    # インベントリ作成
    def self.get_new_profound_inventory(avatar_id, prf_id, owner, start_score = PRF_JOIN_ADD_SCORE)
      if owner
        set_state = PRF_INV_ST_INPROGRESS
      else
        set_state = PRF_INV_ST_NEW
      end
      # inventory作成
      ProfoundInventory.new do |i|
        i.avatar_id = avatar_id
        i.profound_id = prf_id
        i.found = owner
        i.state = set_state
        i.score = start_score # 参加時のスコア加算
        i.save_changes
      end
    end

    # 参加ユーザーのデータ取得
    def self.get_profound_data_list(prf_id)
      ret = []
      inv_list = ProfoundInventory.where(profound_id: prf_id).where { score.positive? }.exclude(state: PRF_INV_ST_FAILED).exclude(state: PRF_INV_ST_GIVE_UP).all
      ret = inv_list if inv_list
      ret
    end

    # 取得済み判定
    def self.is_acquired_profound(avatar_id, hash)
      list = Profound.join(ProfoundInventory.filter(avatar_id:), profound_id: :id).filter(profound_hash: hash).all
      list && !list.empty?
    end

    # 撃破者のインベントリ取得
    def self.get_defeat_user_data(prf_id, _r = true)
      inv_list = ProfoundInventory.where(profound_id: prf_id, defeat: true).all
      inv_list.first if inv_list
    end

    # 撃破判定
    def self.is_defeat_boss(prf_id, _inv_id, _r = true)
      cnt = ProfoundInventory.where(profound_id: prf_id, defeat: true).count
      cnt.positive?
    end

    # 発見者のインベントリ取得
    def self.get_found_user_data(prf_id)
      inv_list = ProfoundInventory.where(profound_id: prf_id, found: true).all
      inv_list.first if inv_list
    end

    # 参加ユーザーのアバターID一覧取得
    def self.get_profound_avatar_list(prf_id)
      ret = []
      inv_list = ProfoundInventory.where(profound_id: prf_id).where { score.positive? }.exclude(state: PRF_INV_ST_FAILED).exclude(state: PRF_INV_ST_GIVE_UP).all
      ret = inv_list.map(&:avatar_id) if inv_list
      ret
    end

    # 参加ユーザー人数取得
    def self.get_profound_avatar_num(prf_id)
      # 発見者情報を取得
      prf = Profound[prf_id]
      finder = Avatar[prf.found_avatar_id] if prf
      # 発見者のフレンドは省くよう調整
      friends_list = finder ? finder.get_friend_avatar_ids : []
      ProfoundInventory.where(profound_id: prf_id).exclude(state: [PRF_INV_ST_FAILED, PRF_INV_ST_GIVE_UP]).exclude(avatar_id: friends_list).all.size
    end

    # 特定ユーザの報酬などの確認が必要な渦を取得
    def self.get_avatar_check_list(avatar_id)
      ProfoundInventory.where(avatar_id:).exclude(reward_state: PRF_INV_REWARD_ST_ALREADY).exclude(state: [PRF_INV_ST_FAILED, PRF_INV_ST_GIVE_UP]).all
    end

    # 特定ユーザの実行中の渦を取得
    def self.get_avatar_battle_list(avatar_id)
      ProfoundInventory.where(avatar_id:).exclude(state: PRF_INV_ST_SOLVED).exclude(state: PRF_INV_ST_FAILED).exclude(state: PRF_INV_ST_GIVE_UP).all
    end

    # 特定ユーザの特定渦を取得
    def self.get_avatar_profound_for_id(avatar_id, prf_id)
      ret = nil
      list = ProfoundInventory.filter([[:avatar_id, avatar_id], [:profound_id, prf_id]]).all
      ret = list.first unless list.empty?
      ret
    end

    # 撃破しているか
    def is_defeat?
      return true unless profound
      return false if is_failed?

      is_defeat = is_solve?
      # Inventoryが終了判定になってない場合
      if is_defeat == false || is_not_end? == false
        is_defeat = profound.is_defeat?
        # 今撃破を確認したので、Stateを変更
        if is_defeat
          solve
        else
          # 撃破していないが、渦は終了している場合、失敗に変更
          self.fail if profound.is_vanished?
        end
      end
      is_defeat
    end

    # 消滅しているか
    def is_vanished?(lt = 0)
      return true unless profound

      ret = profound.is_vanished?(lt)

      # 渦は消えてないが、ギブアップなどをしている場合
      ret ||= state == PRF_INV_ST_FAILED || state == PRF_INV_ST_GIVE_UP
      ret
    end

    # 新規取得か
    def is_new?
      state == PRF_INV_ST_NEW
    end

    # 確認済み
    def inprogress
      if state == PRF_INV_ST_NEW
        self.state = PRF_INV_ST_INPROGRESS
        save_changes
      end
    end

    # 解決済みか
    def is_solve?
      state == PRF_INV_ST_SOLVED
    end

    # 失敗済みか
    def is_failed?
      state == PRF_INV_ST_FAILED || state == PRF_INV_ST_GIVE_UP
    end

    # 解決
    def solve
      if state != PRF_INV_ST_SOLVED && state != PRF_INV_ST_FAILED && state != PRF_INV_ST_GIVE_UP
        self.state = PRF_INV_ST_SOLVED
        save_changes
      end
    end

    # 失敗
    def fail
      if state != PRF_INV_ST_SOLVED && state != PRF_INV_ST_FAILED && state != PRF_INV_ST_GIVE_UP
        self.state = PRF_INV_ST_FAILED
        save_changes
      end
    end

    # ギブアップ
    def give_up
      if state != PRF_INV_ST_SOLVED && state != PRF_INV_ST_FAILED && state != PRF_INV_ST_GIVE_UP
        self.state = PRF_INV_ST_GIVE_UP
        save_changes
        init_ranking(true)
      end
    end

    # 終了してるか判定
    def is_not_end?
      state != PRF_INV_ST_SOLVED && state != PRF_INV_ST_FAILED && state != PRF_INV_ST_GIVE_UP
    end

    # 報酬取得可能状態に変更
    def reward_ready
      if reward_state == PRF_INV_REWARD_ST_STILL
        self.reward_state = PRF_INV_REWARD_ST_READY
        save_changes
      end
    end

    def reward_ready?
      reward_state == PRF_INV_REWARD_ST_READY
    end

    # 報酬取得完了状態に変更
    def reward_already
      if reward_state == PRF_INV_REWARD_ST_READY
        self.reward_state = PRF_INV_REWARD_ST_ALREADY
        save_changes
      end
    end

    def reward_already?
      reward_state == PRF_INV_REWARD_ST_ALREADY
    end

    def get_chara_cards_damages
      [chara_card_dmg_1, chara_card_dmg_2, chara_card_dmg_3]
    end

    # デッキID設定
    def set_deck_idx(deck_idx, r = true)
      refresh if r
      self.deck_idx = deck_idx
      save_changes
    end

    # 戦闘回数を更新
    def update_battle_count(c = 1, r = true)
      refresh if r
      self.btl_count += c
      self.state = PRF_INV_ST_INPROGRESS if state == PRF_INV_ST_NEW
      save_changes
    end

    # スコアを追加する
    def update_score(s, r = true)
      refresh if r
      add_score = 0
      if s.positive?
        r = (rand(PRF_SCORE_RAND_BASIS * 2) - PRF_SCORE_RAND_BASIS)
        add_score = s * PRF_SCORE_ADD_BASIS + r
      end
      SERVER_LOG.info("<AID:#{avatar_id}>RaidServer: [#{__method__}] add score:#{add_score}")
      self.score += add_score
      save_changes
      # ランキングの情報のキャッシュを削除する
      # all_cache_delete
    end

    # 与えたダメージを更新
    def update_damage_count(d = 0, turn = 1, r = true)
      refresh if r
      self.damage_count += d
      save_changes
      score = d > RAID_MAX_DAMAGE_SCORE ? RAID_MAX_DAMAGE_SCORE : d
      SERVER_LOG.info("<AID:#{avatar_id}>RaidServer: [#{__method__}] score:#{score} turn:#{turn}")
      update_score(score, false)
    end

    # 撃破記録
    def update_defeat(d = 0, turn = 1, r = true)
      refresh if r
      self.defeat = true
      self.state = PRF_INV_ST_SOLVED
      update_damage_count(d, turn, false)
      save_changes
    end

    # キャラのダメージを保持
    def update_chara_damage(damage_set, r = true)
      refresh if r
      self.chara_card_dmg_1 = damage_set[0] if damage_set[0]
      self.chara_card_dmg_2 = damage_set[1] if damage_set[1]
      self.chara_card_dmg_3 = damage_set[2] if damage_set[2]
      save_changes
    end

    # 終了時ランキング情報を取得
    def get_finish_ranking_notice_str(defeat_avatar, r = true)
      ranking_str_list = []
      self_rank = ''

      count = 0
      prf_rank_list = get_treasure_rank(r)
      prf_rank_list.each do |rank, list|
        break if count >= FIN_VIEW_RANKING_NUM

        list.each do |data|
          ava = nil
          if defeat_avatar.id == data[:a_id]
            ava = defeat_avatar
          end
          ava ||= Avatar[data[:a_id]]
          if ava
            prf_inv = ProfoundInventory.get_avatar_profound_for_id(ava.id, profound_id)
            r_data = ava.get_profound_rank_from_inv(prf_inv)
            ranking_str_list << "#{rank}&#{ava.name.force_encoding('UTF-8')}&#{r_data[:ret][:score]}" if count < FIN_VIEW_RANKING_NUM
            self_rank = "#{rank}&#{ava.name.force_encoding('UTF-8')}&#{r_data[:ret][:score]}" if data[:a_id] == avatar_id
            count += 1
          end
        end
      end
      if self_rank == ''
        self_ava = Avatar[avatar_id]
        my_rank = get_avatar_treasure_rank(true, avatar_id)
        self_rank = "#{my_rank[:rank]}&#{self_ava.name.force_encoding('UTF-8')}&#{my_rank[:damage]}"
      end
      [ranking_str_list, self_rank]
    end

    # 戦闘終了処理
    def boss_battle_finish
      # 表示するランキングNotice用のデータを作る
      boss_data = profound.p_data.get_boss_data
      boss_name = boss_data ? boss_data.name : 'Boss'
      prf_str = "#{profound_id}_#{profound.p_data.name.force_encoding('UTF-8')}_#{boss_name.force_encoding('UTF-8')}_#{profound.p_data.treasure_level}"
      notice_params = []
      notice_params << { type: NOTICE_TYPE_FIN_PRF_RANKING, param: [prf_str] }

      CACHE.set("profound_btl_fin_notice_#{profound_id}", notice_params, PRF_RANK_NOTICE_CACHE_TIME)
      notice_params
    end

    # 報酬取得可能か判定
    def check_get_reward(r = true)
      refresh if r
      ret = reward_ready?
      if ret == false && reward_state == PRF_INV_REWARD_ST_STILL
        if state == PRF_INV_ST_SOLVED && self.score.positive?
          reward_ready
          ret = true
        end
      end
      ret
    end

    # ノーティス情報をセット
    def set_btl_result_notice(avatar, r = true)
      refresh if r
      params = CACHE.get("profound_btl_fin_notice_#{profound_id}")
      params ||= boss_battle_finish
      if params
        my_rank = get_self_rank
        my_rank_str = "_#{my_rank[:rank]}-#{my_rank[:score]}"
        params.each do |prm|
          prm[:param][0] += my_rank_str
          avatar.write_notice(prm[:type], prm[:param].join(','))
        end
        CACHE.set("profound_btl_fin_notice_#{profound_id}", params, PRF_RANK_NOTICE_CACHE_TIME)
      end
    end

    # 報酬の取得
    def get_reward(avatar, r = true)
      refresh if r
      if reward_state == PRF_INV_REWARD_ST_READY
        boss_data = profound.p_data.get_boss_data
        boss_name = boss_data ? boss_data.name : 'Boss'
        find_ava = Avatar[profound.found_avatar_id] if profound.found_avatar_id != 0
        finder_name = find_ava ? find_ava.name : ''
        prf_str = "#{profound.p_data.name.force_encoding('UTF-8')}_#{boss_name.force_encoding('UTF-8')}_#{finder_name.force_encoding('UTF-8')}"
        notice_head = [prf_str]

        # 自分のランキング情報取得
        rank_data = get_avatar_treasure_rank[avatar.id]
        rank_str = "#{rank_data[:rank]}-#{avatar.name.force_encoding('UTF-8')}-#{rank_data[:damage]}"
        notice_head << rank_str

        # 報酬情報を取得
        rank_bonus, all_bonus, defeat_bonus, found_bonus = profound.get_treasure_list

        reward_list = []

        # 参加報酬
        all_trs_str = avatar.get_profound_tresure(all_bonus)
        reward_list << all_trs_str.join('+')

        # ランキング報酬
        if rank_bonus[rank_data[:rank]]
          rank_trs_str = avatar.get_profound_tresure(rank_bonus[rank_data[:rank]])
          reward_list << rank_trs_str.join('+')
        else
          reward_list << 0.to_s
        end

        # 撃破報酬
        if defeat && profound.set_defeat_reward
          defeat_trs_str = avatar.get_profound_tresure(defeat_bonus)
          reward_list << defeat_trs_str.join('+')
        else
          reward_list << 0.to_s
        end

        # 発見報酬
        if found
          found_trs_str = avatar.get_profound_tresure(found_bonus)
          reward_list << found_trs_str.join('+')
        else
          reward_list << 0.to_s
        end

        # Noticeの作成
        notice_params = []
        notice_params << { type: NOTICE_TYPE_FIN_PRF_WIN,    params: [profound_id, prf_str] }
        notice_params << { type: NOTICE_TYPE_FIN_PRF_REWARD, params: [profound_id, reward_list.join('-')] } unless reward_list.empty?
        notice_params.each do |n_prm|
          avatar.write_notice(n_prm[:type], n_prm[:params].join(','))
        end

        # 報酬状態を完了に変更
        reward_already
      end
    end

    # =========================================
    # Ranking関連処理
    # =========================================
    # ランキングの文字列キャッシュは個別にならないようクラス変数にする
    @@prf_ranking_str_set = {}

    def rank_cache_get(key)
      CACHE.get(key) if key
    end

    def rank_cache_set(key, data, ttl)
      CACHE.set(key, data, ttl) if key
    end

    def rank_cache_delete(key)
      CACHE.delete(key) if key
    end

    # ランキング関連初期化
    def init_ranking(full_clear = false)
      @ranking_all ||= "prf_#{profound_id}_ranking:all"
      @ranking_all_id ||= "prf_#{profound_id}_ranking:all_id"
      @ranking_all_id_before ||= "prf_#{profound_id}_ranking:all_id_before"
      @ranking_arrow ||= "prf_#{profound_id}_ranking:arrow"

      ret = rank_cache_get(@ranking_all)
      inited = ret.nil? || full_clear

      if inited
        all_cache_delete(full_clear)
        get_dmg_ranking
      end
    end

    # 取得Filter
    def get_filter(prf_id)
      ProfoundInventory.where(profound_id: prf_id).exclude(state: PRF_INV_ST_FAILED).exclude(state: PRF_INV_ST_GIVE_UP).order(Sequel.desc(:damage_count))
    end

    # 取得Filter
    def get_score_filter(prf_id)
      ProfoundInventory.where(profound_id: prf_id).exclude(state: PRF_INV_ST_FAILED).exclude(state: PRF_INV_ST_GIVE_UP).order(Sequel.desc(:score))
    end

    # ランキング取得
    def get_dmg_ranking(st_i = 0, end_i = 99, cache = true)
      ret = nil
      ret = rank_cache_get(@ranking_all) if cache
      unless ret
        ret = get_score_filter(profound_id).all
        rank_cache_set(@ranking_all, ret, PRF_RANKING_CACHE_TTL)
        rank_cache_set(@ranking_all_id, ret.map(&:avatar_id), PRF_RANKING_CACHE_TTL)
        create_arrow
      end
      if st_i.zero? && end_i.zero?
        ret
      else
        ret[st_i..end_i]
      end
    end

    # 矢印取得
    def get_arrow_set
      ret = rank_cache_get(@ranking_arrow)
      unless ret
        all_cache_delete
        get_dmg_ranking
        create_arrow
        ret = rank_cache_get(@ranking_arrow)
      end
      ret
    end

    # AvatarIdのみランキング取得
    def get_order_ranking_id(end_i = 0, st_i = 0)
      ret = rank_cache_get(@ranking_all_id)
      unless ret
        ret = get_score_filter(profound_id).all.map(&:avatar_id)
        rank_cache_set(@ranking_all_id, ret, PRF_RANKING_CACHE_TTL)
        create_arrow
      end
      if end_i.zero?
        ret
      else
        ret[st_i..end_i]
      end
    end

    # 矢印データ作成
    def create_arrow
      # 前回の記録があるならばARROWを作る
      before = rank_cache_get(@ranking_all_id_before)
      if before
        arrow_set = []
        a_id_set = rank_cache_get(@ranking_all_id)
        a_id_set ||= get_score_filter(profound_id).all.map(&:avatar_id)
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
        rank_cache_set(@ranking_arrow, arrow_set, PRF_RANKING_CACHE_TTL)
      else
        rank_cache_set(@ranking_arrow, [], PRF_RANKING_CACHE_TTL)
      end
    end

    # キャッシュを削除（矢印作成のために前のランキングを残す）
    def all_cache_delete(full_clear = false)
      if full_clear
        # 完全削除の場合、前のランキングも削除
        rank_cache_delete(@ranking_all_id_before)
      else
        b = rank_cache_get(@ranking_all_id_before)
        unless b && !b.empty?
          rank_cache_set(@ranking_all_id_before, rank_cache_get(@ranking_all_id), RANK_ARROW_TTL)
        end
      end
      rank_cache_delete(@ranking_all)
      rank_cache_delete(@ranking_all_id)
      @@prf_ranking_str_set.each_key do |k|
        rank_cache_delete(k)
      end
      @@prf_ranking_str_set = {}
    end

    # ランキングを文字列で返す（キャッシュつき）
    def get_ranking_str(st_i = 0, end_i = 99, cache = true)
      ret = nil
      if cache
        ret = rank_cache_get("prf_#{profound_id}_ranking:#{st_i}_#{end_i}_str")
      end
      unless  ret
        set = get_dmg_ranking(st_i, end_i, cache)
        arrow_set = get_arrow_set
        ret = []
        if set
          set.each_index do |i|
            avatar = Avatar[set[i].avatar_id]
            name = avatar ? "#{avatar.name} Lv.#{avatar.level}" : ''
            ret << name
            ret << arrow_set[i + st_i]
            ret << set[i].score
          end
        end
        ret = ret.join(',')
        rank_cache_set("prf_#{profound_id}_ranking:#{st_i}_#{end_i}_str", ret, PRF_RANKING_CACHE_TTL)
        @@prf_ranking_str_set["prf_#{profound_id}_ranking:#{st_i}_#{end_i}_str"] = true
      end
      ret
    end

    def arrow_cache_delete
      rank_cache_delete(@ranking_all_id_before)
    end

    # 100位のアバターのポイントを返す
    def last_ranking
      all_set = rank_cache_get(@ranking_all)
      all_set ||= get_dmg_ranking
      if !@max && all_set.count < RANKING_COUNT_NUM
        0
      else
        min = all_set.min { |a, b| (a[:score] <=> b[:score]) }[:score]
        min ||= 0
        min
      end
    end

    # 自分のランクを取得する
    def get_self_rank
      refresh
      index = get_order_ranking_id.index(avatar_id)
      if index && index < RANKING_COUNT_NUM
        ret = { rank: index + 1, arrow: get_arrow_set[index], score: self.score }
      else
        ret = { rank: 0, arrow: RANK_NONE, score: self.score }
      end
      ret
    end

    # 報酬配布用ランキングを取得
    def get_treasure_rank(cache = true)
      ret = rank_cache_get("profound_get_treasure_rank_#{profound_id}") if cache
      unless ret
        init_ranking
        all_cache_delete
        list = get_dmg_ranking(0, 0)
        data_list = {}
        list.each do |l|
          data_list[l.score] = [] unless data_list[l.score]
          data_list[l.score] << { a_id: l.avatar_id, score: l.score }
        end
        rank = 1
        ret = {}
        data_list.each_value do |data|
          count = 0
          data.each do |d|
            ret[rank] = [] unless ret[rank]
            ret[rank] << d
            count += 1
          end
          rank += count
        end
        rank_cache_set("profound_get_treasure_rank_#{profound_id}", ret, 60 * 60 * 24)
      end
      ret
    end

    # 報酬配布用ランキングアバターIDを基準としたものを取得
    def get_avatar_treasure_rank(cache = true, avatar_id = 0)
      ret = rank_cache_get("profound_get_treasure_rank_#{profound_id}_avatar_id") if cache
      unless ret
        init_ranking
        all_cache_delete
        list = get_score_filter(profound_id).all
        data_list = {}
        list.each do |l|
          data_list[l.score] = [] unless data_list[l.score]
          data_list[l.score] << { a_id: l.avatar_id, score: l.score }
        end
        rank = 1
        ret = {}
        data_list.each_value do |data|
          count = 0
          data.each do |d|
            ret[d[:a_id]] = { rank:, damage: d[:score] }
            count += 1
          end
          rank += count
        end
        rank_cache_set("profound_get_treasure_rank_#{profound_id}_avatar_id", ret, 60 * 60 * 24)
      end
      if avatar_id.zero?
        ret
      else
        ret[avatar_id]
      end
    end
  end
end

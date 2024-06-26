# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

require 'model/concerns/avatars/rookie'
require 'model/concerns/avatars/item'
require 'model/concerns/avatars/part'
require 'model/concerns/avatars/quest'

module Unlight
  # アバタークラス
  class Avatar < Sequel::Model
    include Avatars::Rookie
    include Avatars::Item
    include Avatars::Part
    include Avatars::Quest

    NAME_INPUT_SUCCESS = 0 # 名前入力可能
    NAME_ALREADY_USED  = 1 # 使用済み名前
    NAME_CANT_USE      = 2 # 使用不可

    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods

    # 他クラスのアソシエーション
    many_to_one :player                   # プレイヤーに複数所持される
    one_to_many :chara_card_decks         # 複数のデッキを保持
    one_to_many :part_inventories         # 複数のパーツを保持
    one_to_many :quest_logs               # 複数のログをを保持
    one_to_many :avatar_quest_inventories # 複数のクエストを保持
    one_to_many :achievement_inventories # 複数のアチーブメントを保持
    one_to_one :avatar_notice # 一個のログをを保持
    one_to_many :profound_inventories # 複数の渦を保持
    one_to_many :scenario_inventories # 複数のスペシャルなシナリオを保持
    one_to_many :scenario_flag_inventories # シナリオのフラグ
    one_to_one :avatar_apology # 一個のログをを保持

    attr_reader :event, :reward

    # バリデーションの設定
    validates do
      uniqueness_of :name, minimum: 1
    end

    # インサート時の前処理
    before_create do
      self.created_at ||= Time.now.utc
      self.recovery_interval = Unlight::AVATAR_RECOVERY_SEC
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
    end

    # インサート時の後処理
    after_create do
      if chara_card_decks.empty?
        CharaCardDeck.new do |d|
          d.name = 'Binder'
          d.avatar_id = id
          d.save_changes
        end
      end
    end

    # クリスマスイベント処理 12/17 クランプス出現可否の最終チェック時刻
    def get_last_check_time
      ret = @last_check_time
      @last_check_time = Time.now if @last_check_time.nil?

      ret
    end

    # クリスマスイベント処理 12/17 現時刻で可能なクランプスチェックの判定回数を返す
    def get_num_of_retries
      lct = get_last_check_time
      return 0 if lct.nil?

      # 何周期分経過しているか
      num = ((Time.now - lct) / EVENT_201412_CHECK_INTARVAL).to_i
      @last_check_time += EVENT_201412_CHECK_INTARVAL * num if num.positive?

      num
    end

    # クリスマスイベント処理 12/17 プレゼントBOX受け取り済み？
    def present_has_received?
      @present_has_received ? true : false
    end

    attr_writer :present_has_received

    # アバターを登録
    def self.regist(name, pid, parts, cards, server_type = SERVER_SB)
      parts.map!(&:to_i)
      cards.map!(&:to_i)
      ret = false
      # 有効パーツと有効カードをチェックする
      if parts & REGIST_PARTS == parts && cards & REGIST_CARDS == cards
        # 名前以外のデータが有効ならアバター登録開始
        avatar = Avatar.new
        avatar.name = name
        avatar.player_id = pid
        avatar.energy = 5
        avatar.energy_max = 5
        avatar.gems = 100
        avatar.current_deck = 1
        avatar.server_type = server_type
        avatar.favorite_chara_id = CharaCard[cards[0]]&.charactor_id # 選択キャラをお気に入りに設定
        # パーツ所持数が指定と合ってない場合、指定数に変更
        if avatar.part_inventory_max != Unlight::AP_INV_MAX
          avatar.part_inventory_max = Unlight::AP_INV_MAX
        end
        # バリデーション判定して有効だったらDBに保存
        if avatar.valid?
          ret = avatar.save_changes
        end
      end

      # アバターが作られていたらパーツ情報とカード情報を作成
      if ret
        # 空のデッキを作成
        deck = CharaCardDeck.new do |d|
          d.name = 'Deck 1'
          d.avatar_id = avatar.id
          d.save_changes
        end

        CharaCardDeck.new do |d|
          d.name = 'Deck 2'
          d.avatar_id = avatar.id
          d.save_changes
        end

        CharaCardDeck.new do |d|
          d.name = 'Deck 3'
          d.avatar_id = avatar.id
          d.save_changes
        end

        # カードインベントリを作成
        CardInventory.new do |i|
          i.chara_card_deck_id = deck.id
          i.chara_card_id = cards[0]
          i.position = 0
          i.save_changes
        end

        # パーツインベントリを作成して装備する
        parts.each do |p|
          PartInventory.new do |i|
            i.avatar_id = avatar.id
            i.avatar_part_id = p
            i.equip
          end
        end
        # 最後にデフォルト服を登録する
        DEFAULT_CLOTHES.each do |dc|
          PartInventory.new do |pi|
            pi.avatar_id = avatar.id
            pi.avatar_part_id = dc
            pi.equip
          end
        end
        # 最後にデフォルトイベントカードを登録する
        REGIST_EVENT_CARDS.each_index do |idx|
          CharaCardSlotInventory.new do |i|
            i.chara_card_deck_id = avatar.chara_card_decks[0].id
            i.deck_position = 0
            i.card_position = idx
            i.kind = SCT_EVENT
            i.card_id = REGIST_EVENT_CARDS[idx]
            i.save_changes
          end
        end

        # クエストイベント中ならクエストフラグを作製
        avatar.create_event_quest_flag

        # 自分が招待されていたら、招待されていた側にアイテムを追加する
        pl = Player[pid]
        if pl && pl.invited?
          if avatar
            if INVITE_SUCC_LEVEL.zero?
              pl.invite_succeed(name)
            end
            # 自分にも追加する
            notice_str = ''
            invited_item_set = {}
            INVITE_PRESENTS.each do |pre|
              avatar.get_item(pre)
              invited_item_set[pre] = 0 unless invited_item_set[pre]
              invited_item_set[pre] += 1
            end
            pre_no_set = invited_item_set.map do |id, num|
              "#{TG_AVATAR_ITEM}_#{id}_#{num}"
            end
            notice_str += pre_no_set.join(',')
            avatar.write_notice(NOTICE_TYPE_INVITED_SUCC, notice_str)
            # 招待特典ボーナス選択キャラ
            avatar.write_notice(NOTICE_TYPE_GET_SELECTABLE_ITEM, 695.to_s)
          end
        end

        # タグの収集イベントONの時のみ、作製したときに
        avatar.get_item(EVENT_REWARD_ITEM[RESULT_3VS3_WIN][avatar.id.to_s[-1].to_i]) if TAG_COLLECT_EVENT_ON

        # セール時間にする
        avatar.set_one_day_sale_start_check

        SERVER_LOG.info("<UID:#{avatar.player_id}>AuthServer: [#{__method__}] #{avatar.part_inventory_max} #{Unlight::AP_INV_MAX}")
      end
      ret
    end

    # ルーキースタートアップ
    def rookie_present(_player, cards)
      # 初心者キャンペーンフラグ（2016年11月から恒常化）
      if ROOKIE_PRESENT_FLAG
        if self
          notice_str = ''
          pre_no_set = []
          first_choice_card_id = cards[0].to_i
          ROOKIE_PRESENTS.each do |pre|
            set_id = 0
            case pre[:type]
            when TG_GEM
              set_gems(pre[:num])
            when TG_AVATAR_ITEM
              pre[:num].times do |_i|
                get_item(pre[:id])
              end
              set_id = pre[:id]
            when TG_CHARA_CARD
              pre[:num].times do |_i|
                get_chara_card(pre[:id][first_choice_card_id])
              end
              set_id = pre[:id][first_choice_card_id]
            when TG_AVATAR_PART
              pre[:num].times do |_i|
                get_part(pre[:id])
              end
              set_id = pre[:id]
            end
            pre_no_set << "#{pre[:type]}_#{set_id}_#{pre[:num]}"
          end
          notice_str += pre_no_set.join(',')
          write_notice(NOTICE_TYPE_ROOKIE_START, notice_str)
        end
      end
    end

    # アバターを登録
    def self.name_check(name)
      ret = NAME_ALREADY_USED
      return NAME_CANT_USE if /_rename$/.match?(name)

      avatar = Avatar.new
      avatar.name = name
      # バリデーション判定する
      if avatar.valid?
        ret = NAME_INPUT_SUCCESS
      end
      ret
    end

    # バインダーを返す
    def binder
      chara_card_decks[0]
    end

    # バインダーの中にあるコインインベントリを返す
    def coins
      ret = [[], [], [], [], [], []]
      refresh
      binder.card_inventories.each do |c|
        if COIN_CARD_ID <= c.chara_card_id && c.chara_card_id < TIPS_CARD_ID
          ret[c.chara_card_id - COIN_CARD_ID] << c
        elsif EX_COIN_CARD_ID == c.chara_card_id
          ret[5] << c
        end
      end
      ret
    end

    # 特定の武器リストのインベントリを返す
    def get_some_weapon_list(list, r = true)
      refresh if r
      return nil unless list && !list.empty?

      deck_id_list = chara_card_decks.map(&:id)
      CharaCardSlotInventory.where(chara_card_deck_id: deck_id_list, kind: SCT_WEAPON, card_id: list).all
    end

    # デュエルに使用するデッキを返す
    def duel_deck
      refresh
      chara_card_decks[current_deck]
    end

    # カードが変換可能か
    def exchangeable?(id, c_id)
      # 各カードの枚数を格納するハッシュ
      nums = Hash.new([])
      # バインダーに入ったカードを種類ごとに枚数を列挙する
      binder.refresh
      binder.card_inventories.each { |c| nums[c.id] << c }
      CharaCard.exchange(id, nums, c_id)[0]
    end

    # カードを変換(成長)する(目標id, キャラクターID)
    def exchange(id, c_id)
      refresh
      # 各カードの枚数を格納するハッシュ
      nums = Hash.new { |hash, key| hash[key] = [] }
      # バインダーに入ったカードを種類ごとに枚数を列挙する
      binder.card_inventories.each { |c| nums[c.chara_card_id] << c }
      ex = CharaCard.exchange(id, nums, c_id)
      ret = []
      inv_id = 0
      if ex[0]
        ex[1].each do |k, v|
          v.times do |_i|
            ret << nums[k].last.id
            nums[k].pop.delete_from_deck
          end
          SERVER_LOG.info("<UID:#{player_id}>Avatar: [exchange succ] CCID:#{k} Remain Num:#{nums[k].size}")
        end
        CardInventory.new do |c|
          c.chara_card_deck_id = binder.id
          c.chara_card_id = id
          c.save_changes
          inv_id = c.id
        end
        # 取得したカードに関係しているもののみ、更新チェック 2013/01/18 yamagishi
        achievement_check(Achievement.get_card_check_achievement_ids([id]), { is_update: true, list: [id] })
        # Lv、レアカード作成レコードチェック
        get_card_level_record_check([id])
      end
      # 成功したか, 得られたカードID, 得られたカードのインベントリID失うカード,失うカードのインベントリID
      [ex[0], id, inv_id, ret]
    end

    # 武器カード合成
    def combine(inv_id_list)
      # ベースカード情報を抜き出す
      base_id = inv_id_list.shift
      # 素材カードのインベントリIDを配列に入れなおす
      set_id_list = inv_id_list.map(&:to_i)
      # 素材カードのインベントリを取得
      sci_set = binder.get_slot_card_inventory(set_id_list)
      # ベースカードのインベントリを取得
      base_sci = CharaCardSlotInventory[base_id]
      # ベースカードインベントリがない、素材カードインベントリがない場合は合成しない
      return [false, 0, 0] if base_sci.nil? || sci_set.size <= 0

      # 素材のCombineCaseを配列にまとめる
      combine_case_set = []
      use_card_ids = []
      sci_set.each do |c|
        combine_case_set.concat(c.card.combine_cases)
        use_card_ids << c.card_id
      end

      # 専用武器かどうかを保持
      pre_weapon_restriction = base_sci.card.restriction

      # CombineCaseが複数あり、既に専用武器の場合、現状の武器IDは排除する
      if combine_case_set.size > 1
        if pre_weapon_restriction != '' && CHARA_GROUP_MEMBERS[pre_weapon_restriction].nil?
          combine_case_set = combine_case_set.reject { |cc| cc.combined_w_id == base_sci.card_id }
        end
      end

      # 合成前パラメータをログに書き込み
      base_sci.write_log(player_id)

      # 合成処理
      result = CombineCase.combine(base_sci.card_id, sci_set.map(&:card_id), combine_case_set)

      SERVER_LOG.info("<UID:#{player_id}>Avatar: [#{__method__}_result] base_inv:#{base_id} base_card_id:#{base_sci.card_id} use_invs:#{inv_id_list} use_card_ids:#{use_card_ids} result:#{result}")

      success = false
      if result.keys.empty?
        use_card_ids.each do |cid|
          if COMB_EXP_ITEM_IDS.include?(cid)
            success = true
            break
          end
        end
      else
        success = true
      end
      updated = false

      if success
        # 合成結果を反映
        updated = base_sci.combine_update(result)
        base_sci.update_exp(sci_set, false)
        base_sci.save_changes
      end

      # 合成後パラメータをログに書き込み
      base_sci.write_log(player_id, true)

      if updated
        # バインダーから取得しても更新されているようリフレッシュ
        binder.refresh_inventory(base_sci.id)
        SERVER_LOG.info("<UID:#{player_id}>Avatar: [#{__method__}] aft_weapon_restriction#{base_sci.card.restriction}")
        base_sci.change_restriction_act if pre_weapon_restriction == '' && base_sci.card.restriction != ''
        # 使用した素材を削除
        sci_set.each(&:delete_from_deck)

        # 更新内容をクライアントに通知
        if @event
          @event.update_combine_weapon_data_event(
            base_sci.id, # inv_id
            base_sci.card_id, # card_id
            base_sci.combine_base_sap, # base_sap
            base_sci.combine_base_sdp, # base_sdp
            base_sci.combine_base_aap, # base_aap
            base_sci.combine_base_adp, # base_adp
            base_sci.combine_base_max, # base_max
            base_sci.combine_add_sap, # add_sap
            base_sci.combine_add_sdp, # add_sdp
            base_sci.combine_add_aap, # add_aap
            base_sci.combine_add_adp, # add_adp
            base_sci.combine_add_max, # add_max
            base_sci.get_all_passive_id.join('|'), # passive_id
            base_sci.card.restriction, # restriction
            base_sci.combine_cnt_str, # cnt
            base_sci.combine_cnt_max_str, # cnt_max
            base_sci.level, # level
            base_sci.exp, # exp
            base_sci.combine_passive_num_max, # passive_num_max
            base_sci.combine_passive_pass_set.join('|') # passive_pass_set
          )
        end
      end

      [success, base_sci.card_id, base_sci.id]
    end

    # アバターパーツの数を返す
    def parts_num
      part_inventories.size
    end

    # カードの枚数を返す
    def cards_num
      ret = 0
      chara_card_decks.each { |d| ret += d.card_inventories.size } if chara_card_decks
      ret
    end

    # デッキ数を返す
    def decks_num
      chara_card_decks.size
    end

    # クエスト数を返すことが出来る
    def quests_num
      avatar_quest_inventories.size
    end

    # スロットカードの枚数を返す
    def slots_num
      ret = 0
      chara_card_decks.each { |d| ret += d.chara_card_slot_inventories.size } if chara_card_decks
      ret
    end

    # パーツインベントリリストからIDが適合するものを返す
    def part_from_inventories(p_id, r = true)
      ret = nil
      refresh if r
      part_inventories.each do |pi|
        if pi.id == p_id
          ret = pi
          break
        end
      end
      ret
    end

    # タイムオーバーしたパーツを調べる
    def check_time_over_part(r = true)
      refresh if r
      part_inventories.each do |pi|
        if pi.work_end?
          SERVER_LOG.info("<UID:#{player_id}>Avatart:[chck_time_over] #{pi.id}")
          vanish_part_event(pi.id) if @event
        end
      end
    end

    # アバターパーツを装備する(同じインベントリを装備しようとすると外れる)
    def equip_part(inv_id)
      ret = [0, 0, []]
      i = part_from_inventories(inv_id)
      if i
        # 期限切れなら捨てられて終わり
        if i.work_end?
          SERVER_LOG.info("<UID:#{player_id}>Avatart:[chck_time_over] #{i.id}")
          vanish_part_event(i.id) if @event
          return ret
        end

        # 装備済みならはずす。そうでないなら付ける
        if i.equiped?
          i.unequip
          ret[2] << i.id
        else
          # 素体の交換のみ例外的に重複パーツを取り除かない(何もないときにも出すから)
          if i.avatar_part.parts_type == APT_B_BODY
            part_inventories.each do |p|
              if p.avatar_part.parts_type == APT_B_BODY && p.equiped?
                p.unequip
                ret[2] << p.id
              end
            end
          else
            # 装備しようとするインベントリからパーツ位置を取り出す
            str1 = i.avatar_part.image.split('+').map { |e| e[e.rindex('_p') + 2..] }
            part_inventories.each do |p|
              # すべての使用中パーツに関してパーツの重複をしらべる（素体は除く）
              if p.equiped? && p.avatar_part && (p.avatar_part.parts_type != APT_B_BODY)
                str2 = p.avatar_part.image.split('+').map { |e| e[e.rindex('_p') + 2..] }
                # 装備するアイテムと装備中のアイテムを比較し重複していたら外す
                if (str1 & str2).count.positive?
                  p.unequip
                  ret[2] << p.id
                end
              end
            end
          end
          i.equip
          ret[1] = inv_id
          ret[3] = i.get_end_at(Time.now.utc)
          ret[4] = i.used
        end
      else
        ret[0] = ERROR_CANT_EQUIP
      end
      ret
    end

    # パーツを捨てる
    def part_drop(inv)
      if inv.avatar_id == id
        SERVER_LOG.info("<UID:#{player_id}>Avatart:[part drop] #{inv.id}")
        if inv.equiped?
          inv.unequip
        end
        inv.vanish_part
        vanish_part_event(inv.id, false) if @event
      end
    end

    # すべての装備パーツをチェックする
    def all_equiped_parts_check
      Unlight::AvatarPart.all_params_check(get_equiped_parts_list).each do |k, v|
        method(k).call(v)
      end
    end

    # カードのIDのリストを返す
    def cards_list_str(r = true, cards_arr = nil)
      if cards_arr.nil?
        cards_list(r).join(',')
      else
        cards_arr.join(',')
      end
    end

    # カードのIDのリストを返す
    def cards_list(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.card_inventories.each do |c|
          ret << c.chara_card_id
        end
      end
      ret
    end

    # カードのインベントリIDのリストを返す
    def inventories_list_str(r = true)
      inventories_list(r).join(',')
    end

    # キャラカードのインベントリのリストを返す
    def inventories_list(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.card_inventories.each do |c|
          ret << c.id
        end
      end
      ret
    end

    # カードスロットのデッキ番号のリストを返す
    def slot_deck_index_list_str(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          ret << chara_card_decks.index(c.chara_card_deck)
        end
      end
      ret.join(',')
    end

    # カードスロットのIDのリストを返す
    def slots_list_str(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          ret << c.card_id
        end
      end
      ret.join(',')
    end

    # カードスロットの種類のリストを返す
    def slot_type_list_str(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          ret << c.kind
        end
      end
      ret.join(',')
    end

    # カードスロットのインベントリIDのリストを返す
    def slot_inventories_list_str(r = true)
      slot_inventories_list(r).join(',')
    end

    # カードスロットのインベントリのリストを返す
    def slot_inventories_list(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          ret << c.id
        end
      end
      ret
    end

    # カードスロットのインベントリの合成かどうかリストの文字列を返す
    def slot_combined_list_str(r = true)
      slot_combined_list(r).join(',')
    end

    # カードスロットのインベントリの合成かどうかリストを返す
    def slot_combined_list(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          ret << c.combined?
        end
      end
      ret
    end

    # カードスロットのインベントリの合成データリストの文字列を返す
    def slot_combine_data_list_str(r = true)
      slot_combine_data_list(r).join(',')
    end

    # カードスロットのインベントリの合成データリストを返す
    def slot_combine_data_list(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          if c.combined?
            set = []
            set << c.level
            set << c.exp
            set << c.combine_param1_upper
            set << c.combine_param1_lower
            set << c.combine_param2
            set << c.combine_param3
            ret << set.join('|')
          end
        end
      end
      ret
    end

    # カードスロットのデッキ内インデックスを返す
    def slot_deck_position_list_str(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          ret << c.deck_position
        end
      end
      ret.join(',')
    end

    # カードスロットのカード内インデックスを返す
    def slot_card_position_list_str(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.chara_card_slot_inventories.each do |c|
          ret << c.card_position
        end
      end
      ret.join(',')
    end

    # 保有しているキャラカードで最大レベル,最大レアリティのカードを返す
    def max_cc_level_get(c_id)
      level = 0
      rare = 0
      ret = nil
      refresh
      chara_card_decks.each do |d|
        d.cards.each do |c|
          # キャラが同一で
          if c.charactor_id == c_id
            # レベルが今までと最高
            if c.level >= level
              # かつレア度が高い
              level = c.level
              if c.rarity >= rare
                rare = c.rarity
                ret = c
              elsif c.level > level
                ret = c
              end
            end
          end
        end
      end
      ret
    end

    def get_deck_index(d)
      chara_card_decks.index(d)
    end

    # カードのデッキ番号のリストを返す
    def deck_index_list_str(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.card_inventories.each do |c|
          ret << chara_card_decks.index(c.chara_card_deck)
        end
      end
      ret.join(',')
    end

    # カードのデッキ内インデックスを返す
    def deck_position_list_str(r = true)
      ret = []
      refresh if r
      chara_card_decks.each do |d|
        d.card_inventories.each do |c|
          ret << c.position
        end
      end
      ret.join(',')
    end

    # デッキの名前を更新する
    def update_deck_name(index, name)
      if index.positive? && index < chara_card_decks.size
        chara_card_decks[index].name = name
        chara_card_decks[index].save_changes
      else
        raise 'undefined deck'
      end
    end

    # デッキの名前のリストを返す
    def deck_name_list_str(r = true)
      refresh if r
      ret = chara_card_decks.map(&:name)
      ret.join(',')
    end

    # デッキの種類のリストを返す
    def deck_kind_list_str(r = true)
      refresh if r
      ret = chara_card_decks.map do |d|
        d.kind.to_s
      end
      ret.join(',')
    end

    # デッキのレベルリストを返す
    def deck_level_list_str(r = true)
      refresh if r
      ret = chara_card_decks.map do |d|
        d.level.to_s
      end
      ret.join(',')
    end

    # デッキの経験値リストを返す
    def deck_exp_list_str(r = true)
      refresh if r
      ret = chara_card_decks.map do |d|
        d.exp.to_s
      end
      ret.join(',')
    end

    # デッキの現在のステータスのリストを返す
    def deck_status_list_str(r = true)
      refresh if r
      ret = chara_card_decks.map do |d|
        d.status.to_s
      end
      ret.join(',')
    end

    # デッキの現在のコストのリストを返す
    def deck_cost_list_str(r = true)
      refresh if r
      ret = chara_card_decks.map do |d|
        d.current_cost.to_s
      end
      ret.join(',')
    end

    # デッキのマックスコストのリストを返す
    def deck_max_cost_list_str(r = true)
      refresh if r
      ret = chara_card_decks.map do |d|
        d.max_cost.to_s
      end
      ret.join(',')
    end

    # 指定したデッキの名前を返す
    def deck_name(index)
      if chara_card_decks[index].nil?
        raise 'undefined deck'
      else
        chara_card_decks[index].name
      end
    end

    # カレントキャラカード
    def current_cards_ids
      ret = [-1, -1, -1]
      refresh
      if chara_card_decks[current_deck]
        chara_card_decks[current_deck].card_inventories.each_index do |i|
          ret[i] = chara_card_decks[current_deck].card_inventories[i].chara_card_id
        end
      end
      ret.join(',')
    end

    # クエストログの特定ページをのログを返す
    def get_quest_log(page)
      QuestLog.get_page(id, page)
    end

    # クエストログにのログを書き込む
    def set_quest_log(body)
      QuestLog.write_log(id, QuestLog::TYPE_AVATAR, id, name, body)
    end

    # デュエルで使用するカードのIDをカンマ区切り文字列で返す
    def duel_deck_cards_id_str
      if duel_deck
        duel_deck.cards_id.join(',')
      else
        ''
      end
    end

    # デュエルで使用するカードのIDをカンマ区切り文字列で返す
    def duel_deck_mask_cards_id_str
      if duel_deck
        duel_deck.mask_cards_id.join(',')
      else
        ''
      end
    end

    # カレントデッキを変更する
    def update_current_deck_index(index)
      if index.positive? && chara_card_decks[index]
        self.current_deck = index
        save_changes
      end
    end

    # 新規にデッキを作る
    def create_deck(exp = 0, list = [])
      CharaCardDeck.new do |d|
        d.name = "Deck #{decks_num}" # Binderを含む個数の為、一つ分増加しなくても1増えた数字になる
        d.avatar_id = id
        d.set_deck_exp(exp, 0, false)
        while d.check_deck_level_up(false)
        end
        d.save_changes
        chara_card_decks << d
        cards = []
        chara_pos = -1
        event_pos = 0
        weapon_pos = 0
        list.each do |h|
          h[:inv].chara_card_deck_id = d.id
          case h[:type]
          when RMI_TYPE_EVENT_CARD
            h[:inv].card_position = event_pos
            event_pos += 1
            h[:inv].deck_position = chara_pos
            cards << [RMI_TYPE_EVENT_CARD, h[:inv].id]
          when RMI_TYPE_WEAPON_CARD
            h[:inv].card_position = weapon_pos
            weapon_pos += 1
            h[:inv].deck_position = chara_pos
            cards << [RMI_TYPE_WEAPON_CARD, h[:inv].id]
          when RMI_TYPE_CHARA_CARD
            chara_pos += 1
            h[:inv].position = chara_pos
            event_pos = 0
            weapon_pos = 0
            cards << [RMI_TYPE_CHARA_CARD, h[:inv].id]
          end
          h[:inv].save_changes
        end

        @event.deck_get_event(d.name, d.kind, d.level, d.exp, d.status, d.current_cost, d.max_cost, cards.join(',')) if @event
      end
      0
    end

    # 指定したデッキを消去する
    def delete_deck(index)
      ret = false
      if index.positive? && chara_card_decks[index] && chara_card_decks.size > 2
        chara_card_decks[index].destroy
        ret = true
      else
        ret = false
      end
      refresh
      ret
    end

    # デッキからカードを取り除いたときに残されたデッキ正しいポジションで返す
    def removed_deck_remain_card_update(old_deck)
      list = old_deck.position_list_card
      list.each_index do |i|
        update_chara_card_deck(list[i], chara_card_decks.index(old_deck), i)
      end
    end

    # 所持キャラカードの情報を更新する
    def update_chara_card_deck(inv_id, index, position)
      if chara_card_decks[index]
        if (chara_card_decks[index].card_inventories.size > CHARA_CARD_DECK_MAX) && index.positive?
          return ERROR_DECK_MAX
        end

        # インベントリが存在して、かつそれが自分のインベントリそして目標のデッキが存在する場合に進む
        a = CardInventory[inv_id]
        if a && inventories_list.include?(a.id)
          ret = 0
          # キャラカードのキャラIDの重複をチェック(バインダーでないならば)
          ret = chara_card_decks[index].chara_card_check(a) unless index.zero?
          if ret.zero?
            old_deck = a.chara_card_deck
            a.chara_card_deck = chara_card_decks[index]
            a.position = position
            # 移動もとがバインダーでない場合は同じデッキの同じデッキポジションのSlotカードもすべて移動させる
            a.save_changes
            # もしカードがデッキからバインダーでなく、同じデッキ間の移動でなければ残りカードをしらべてポジションをずらす
            removed_deck_remain_card_update(old_deck) if old_deck != chara_card_decks[index] && old_deck != binder
            0
          else
            ret
          end
        else
          ERROR_NOT_EXIST_INVETORY

        end
      else
        ERROR_NOT_EXIST_DECK

      end
    end

    # 所持スロットカードの情報を更新する
    def update_slot_card_deck(inv_id, index, kind, deck_position, card_position)
      refresh
      if chara_card_decks[index]
        # インベントリが存在して、かつそれが自分のインベントリそして
        a = CharaCardSlotInventory[inv_id]
        if a && slot_inventories_list.include?(inv_id)
          # 目標デッキのスロットに入るかチェックする（バインダの場合はチェックしないでかならず更新）
          ret = 0
          ret = chara_card_decks[index].slot_check(kind, a.card_id, deck_position, a) if index != 0
          # スロットのチェックがOKまたはバインダの場合は更新する
          if ret.zero?
            a.chara_card_deck = chara_card_decks[index]
            a.deck_position = deck_position
            a.card_position = card_position
          else
            a.chara_card_deck = chara_card_decks[0]
          end
          a.save_changes
          return [ret, a]
        end
        raise 'wrong card inventory id'
      end
    end

    # 不正終了などで変なカードがはいってしまった場合などを考慮してデッキから不正なカードを取り除く
    def deck_clean_up_all
      chara_card_decks.each do |d|
        deck_clean_up(d)
      end
    end

    # 不正終了などで変なカードがはいってしまった場合などを考慮してデッキから不正なカードを取り除く
    def deck_clean_up(deck)
      ret = true
      # チェックするデッキがバインダーで無い場合
      unless deck == binder
        d = deck
        cs = deck.cards(false)
        # デッキに3枚以上入っていないか？
        if d && cs.size > CHARA_CARD_DECK_MAX
          ret = false
        end
        # デッキの先頭にモンスターが入っていないか？
        if ret && d && !cs.empty?
          unless [CC_KIND_CHARA, CC_KIND_REBORN_CHARA, CC_KIND_RENTAL, CC_KIND_EPISODE].include?(cs[0].kind)
            ret = false
          end
        end
        # デッキの同じキャラが2人以上はいっていないか？
        if ret && d
          r = 0
          d.card_inventories.clone.each do |cci|
            r = d.chara_card_check(cci)
            unless r.zero?
              ret = false
            end
          end
        end
        # デッキの前寄りに空席がないか
        if ret && d && !cs.empty?
          d.card_inventories.clone.each do |cci|
            if cci.position >= cs.size
              ret = false
            end
          end
        end

        # キャラが存在しないのにイベントカードや装備カードが存在していないか？
        if ret
          d.chara_card_slot_inventories.each do |si|
            unless d.slot_check(si.kind, si.card_id, si.deck_position, si, false).zero?
              ret = false
            end
          end
        end
      end

      # 一つでも不正があればデッキはバインダーに戻る
      unless ret
        if d
          d.deck_reset(binder)
          SERVER_LOG.info("Avatar: [deck_reset] ID: #{d.id}")
        end
      end
      ret
    end

    # 更新されたデータをチェックする
    def update_check(r = true)
      tmp_exp = exp
      tmp_gems = gems
      tmp_energy_max = energy_max
      tmp_level = level
      tmp_point = point
      tmp_win = win
      tmp_lose = lose
      tmp_draw = draw
      energy_recovery_check(r) # ここでrefreshする
      if @event
        @event.get_exp_event unless tmp_exp == exp
        @event.update_gems_event unless tmp_gems == gems
        @event.use_energy_event(false)
        @event.use_free_duel_count_event(false)
        @event.update_energy_max_event unless tmp_energy_max == energy_max
        @event.level_up_event unless tmp_level == level
        @event.update_result_event if tmp_win != win || tmp_lose != lose || tmp_draw != draw || tmp_point != point
        @event.get_deck_exp_event
        @event.deck_level_up_event
      end
    end

    def parts_update_chek; end

    # 経験値をセット
    def set_exp(i, r = true)
      refresh if r
      self.exp += i
      save_changes
      check_level_up
      @event.get_exp_event if @event
    end

    # レベルアップをチェック
    def check_level_up
      if self.exp >= LEVEL_EXP_TABLE[level]
        self.energy_max = energy_max + LEVEL_ENG_BOUNUS[level]
        self.energy = energy_max if energy < energy_max
        self.level += 1
        save_changes
        @event.level_up_event if @event
        if INVITE_SUCC_LEVEL == self.level
          Player[player_id].invite_succeed(name)
        end
        check_level_up
      end
    end

    # デッキ経験値をセット
    def set_duel_deck_exp(i, is_get_bp = 0)
      set_deck_exp(duel_deck, i, is_get_bp)
    end

    def set_deck_exp(d, i, is_get_bp = 0)
      d.set_deck_exp(i, is_get_bp)
      @event&.deck_level_up_event while d.check_deck_level_up
      @event.get_deck_exp_event if @event
    end

    # ジェムをセット
    def set_gems(i, r = true)
      refresh if r
      self.gems += i
      save_changes
      @event.update_gems_event if @event
      0
    end

    # クエストポイントをゲット
    def set_quest_point(i)
      refresh
      self.quest_point += i
      save_changes
      Unlight::TotalQuestRanking.update_ranking(id, name, self.quest_point, server_type)
      @event.update_quest_point_event if @event
    end

    # 勝敗結果の保存
    def set_result(result, win_bp, lose_bp, is_get_bp)
      point_calc = 0
      # レーティングポイントの変動
      if win_bp.positive? && lose_bp.positive?
        point_calc = 16 + ((lose_bp - win_bp) * 0.04).to_i
        point_calc = 1 if point_calc.negative?
      end
      # 平行して勝ち負けが走るのでリフレッシュ
      refresh
      # 勝敗を保存
      case result
      when RESULT_WIN
        self.win += 1
        self.point += point_calc if is_get_bp == 1
        save_changes # チェックの前に保存する
      when RESULT_LOSE
        self.lose += 1
        self.point -= point_calc if is_get_bp == 1
        self.point = 0 if is_get_bp == 1 && self.point.negative?
        save_changes
      when RESULT_DRAW
        self.draw += 1
        save_changes
      end
      Unlight::TotalDuelRanking.update_ranking(id, name, self.point, server_type)
      if EVENT_DUEL_01[0].include?(result)
        achievement_check(EVENT_DUEL_01[1])
      end
      # タリスマンイベントの排他チェック
      achievement_check([356, 361])
      @event.update_result_event if @event
    end

    # イベントデュエル勝利時の判定
    def set_special_result(result)
      if EVENT_CPU_DUEL_01[0].include?(result)
        achievement_check(EVENT_CPU_DUEL_01[1])
      end
    end

    # Duel相手のIDを保持
    def duel_foe_avatar_check_match_log
      list = MatchLog.filter(a_avatar_id: id).or(b_avatar_id: id).filter { start_at > RECORD_OTHER_AVATAR_DUEL_CHECK_START }.all

      other_avatar_ids = list.map do |ml|
        ml.other_avatar_id(id)
      end
      other_avatar_ids.uniq!

      SERVER_LOG.info("<UID:#{id}> [#{__method__}] list:#{other_avatar_ids}")
      other_avatar_ids
    end

    # Duel相手のIDリストを取得
    def duel_foe_avatar_get_cache
      ret = duel_foe_avatar_check_match_log
      SERVER_LOG.info("<UID:#{id}> [#{__method__}] list:#{ret}")
      ret
    end

    # 行動力の回復をチェック
    def energy_recovery_check(r = true)
      refresh if r
      unless  energy_max?
        if last_recovery_at
          t = Time.now.utc - last_recovery_at.utc
        else
          self.last_recovery_at = Time.now.utc
          save_changes
          t = 0
        end
        # 過ぎた時間が回復感覚より大きければ回復
        recov = t.divmod(get_recovery_interval)
        if (recov[0]).positive?
          recovery_energy(recov[0], false)
          self.last_recovery_at = Time.now.utc - recov[1]
          save_changes
          # 次の残り時間を更新する
          if energy_max?
            @event.update_remain_time_event(0, false) if @event
          else
            @event.update_remain_time_event(get_recovery_interval - recov[1], false) if @event
          end
        else
          @event.update_remain_time_event(get_recovery_interval - recov[1], false) if @event
        end
      end
    end

    # 現在の行動力はMAXか?
    def energy_max?
      energy == energy_max
    end

    # 行動力を使う
    def energy_use(x)
      refresh
      # 残りより多いならば実行
      if energy >= x
        # 最初に減る場合はリカバリータイマーをリセット
        self.last_recovery_at = Time.now.utc if energy_max?
        self.energy -= x
        save_changes
        @event.use_energy_event(false) if @event
      end
      self.energy
    end

    # 行動力を回復
    def recovery_energy(x, r = true)
      refresh if r
      if energy_max > self.energy
        self.energy += x
        self.energy = energy_max if self.energy > energy_max
        save_changes
        @event.use_energy_event(false) if @event
        true
      else
        false
      end
    end

    # 行動力を回復
    def recovery_energy_force(x, r = true)
      refresh if r
      self.energy += x
      save_changes
      @event.use_energy_event(false) if @event
      true
    end

    # 行動力回復間隔を設定
    def set_recovery_interval(i)
      self.recovery_interval = i
      save_changes
    end

    # 行動力回復間隔をゲット
    def get_recovery_interval
      recovery_interval < 1 ? 1 : recovery_interval
    end

    # クエスト短縮係数をゲット
    def get_quest_find_pow
      refresh
      quest_find_pow < 1 ? 1 : quest_find_pow
    end

    # 次の回復時間を返す
    def get_next_recovery_time(r = true)
      refresh if r
      ret = 0
      if last_recovery_at && !energy_max?
        t = Time.now.utc
        # もし最終回復時間がおかしかったら最終回復時間を直す
        if last_recovery_at > t
          self.last_recovery_at = t
          save_changes
        end
        ret = get_recovery_interval - (t - last_recovery_at).to_i
      end
      ret.positive? ? ret : 0
    end

    # 現在の行動力を返す
    def get_energy
      refresh
      self.energy
    end

    # そのAPを消費可能か？のチェック
    def check_energy(ap)
      if ap.nil?
        false
      else
        refresh
        self.energy >= ap
      end
    end

    # 指定したアバターパーツを取得する
    def get_part(part_id, check = false)
      ret = false
      # すでに持っていたら追加しない
      if check && parts_dupe_check(part_id)
        ret =  ERROR_PARTS_DUPE
        return ret
      end
      # パーツが存在するならば追加
      if AvatarPart[part_id]
        inv = PartInventory.new do |i|
          i.avatar_id = id
          i.avatar_part_id = part_id
          i.save_changes
        end
        @event.part_get_event(inv.id, part_id) if @event
        ret = true

        # レコードチェック
        if EVENT_GET_PART_01[0].include?(part_id)
          achievement_check(EVENT_GET_PART_01[1])
        end
        if EVENT_GET_PART_02[0].include?(part_id)
          achievement_check(EVENT_GET_PART_02[1])
        end
        if EVENT_GET_PART_03[0].include?(part_id)
          achievement_check(EVENT_GET_PART_03[1])
        end
      end
      ret
    end

    # 指定した効果のアイテムを取得する
    def get_item(item_id)
      SERVER_LOG.info("<UID:#{id}> [avatar.get_item] item_id:#{item_id}")
      ret = false
      if AvatarItem[item_id]
        # アイテムインベントリを追加
        inv = ItemInventory.new do |i|
          i.avatar_id = id
          i.avatar_item_id = AvatarItem[item_id].id
          i.state = ITEM_STATE_NOT_USE
          i.server_type = server_type
          i.save_changes
        end
        @event.item_get_event(inv.id, item_id) if @event
        ret = true
      end

      # キャラ人気投票レコードチェック
      if CHARA_VOTE_EVENT && ret && CHARA_VOTE_ITEM_ID_LIST.include?(item_id)
        achievement_check(CHATA_VOTE_ACHIEVEMENT_IDS)
      end

      # 使用済み含む全所持数チェックレコード
      if EVENT_ITEM_FULL_CHECK_IDS[0].include?(item_id)
        achievement_check(EVENT_ITEM_FULL_CHECK_IDS[1])
      end

      ret
    end

    # 指定したカード取得する
    def get_slot_card(sct_type, card_id, check_record = true)
      get_weapon = false
      ret = false
      case sct_type
      when SCT_WEAPON
        if WeaponCard[card_id]
          ret = true
          get_weapon = true
        end
      when SCT_EQUIP
        ret = true if EquipCard[card_id]
      when SCT_EVENT
        ret = true if EventCard[card_id]
      end
      if ret
        # アイテムインベントリを追加
        inv = CharaCardSlotInventory.new do |i|
          i.chara_card_deck_id = binder.id
          i.deck_position = 0
          i.card_position = 0
          i.kind = sct_type # サーバー側はtyoe0から開始なので
          i.card_id = card_id
          i.save_changes
        end

        @event.slot_card_get_event(inv.id, inv.kind, card_id) if @event
        ret = inv
        if check_record
          achievement_check(GET_WEAPON_ACHIEVEMENT_IDS) if GET_WEAPON_ACHIEVEMENT_IDS && get_weapon
        else
          @get_weapon_record_check = get_weapon
        end
      end
      ret
    end

    # 指定したキャラカード取得する
    def get_chara_card(card_id)
      c = CharaCard[card_id]
      c.nil? ? ret = false : ret = true
      if ret
        # カードインベントリを作成
        inv = CardInventory.new do |i|
          i.chara_card_deck_id = binder.id
          i.chara_card_id = card_id
          i.position = 0
          i.save_changes
        end
        # 取得したカードに関係しているもののみ、更新チェック
        achievement_check(Achievement.get_card_check_achievement_ids([card_id]), { is_update: true, list: [card_id] })
        # Lv、レアカード作成レコードチェック
        get_card_level_record_check([card_id])
        @event.chara_card_get_event(inv.id, card_id) if @event
        ret = inv
      end
      ret
    end

    # 指定した効果のアイテムを使用する
    def use_item(inv_id, quest_map_no = 0)
      # インベントリにあるか調べる
      ret = ERROR_ITEM_NOT_EXIST
      refresh
      it = ItemInventory[inv_id]
      if it && it.state == ITEM_STATE_NOT_USE && it.avatar_id == id
        # 使用する
        ret = it.use(self, quest_map_no)
        @event.item_use_event(it.id) if @event && ret.zero?
        achievement_check(EVENT_USE_ITEM_RECORD_ID[1]) if EVENT_USE_ITEM_RECORD_ID[0].include?(it.avatar_item_id) && ret.zero?
      end
      ret
    end

    # 渦情報送信
    def send_prf_info(inv, r = true)
      refresh if r
      if inv
        close_at_str = inv.profound.close_at.nil? ? '' : inv.profound.close_at.strftime('%a %b %d %H:%M:%S %Z %Y')
        created_at_str = inv.profound.created_at.strftime('%a %b %d %H:%M:%S %Z %Y')
        now_damage, = ProfoundLog.get_now_damage(id, inv.profound.id)
        deck_status = inv.deck_idx.zero? ? CDS_NONE : chara_card_decks[inv.deck_idx].status
        if inv.profound.state == PRF_ST_FINISH && deck_status != CDS_NONE
          chara_card_decks[inv.deck_idx].status = CDS_NONE
          chara_card_decks[inv.deck_idx].save_changes
          deck_status = CDS_NONE
        end
        finder = Avatar[inv.profound.found_avatar_id]
        if finder
          finder_id = finder.id
          finder_name = finder.name.force_encoding('UTF-8')
        else
          finder_id = 0
          finder_name = ''
        end

        if @event
          @event.send_profound_info_event(inv.profound.data_id,
                                          inv.profound.profound_hash,
                                          close_at_str,
                                          created_at_str,
                                          inv.profound.state,
                                          inv.profound.map_id,
                                          inv.profound.pos_idx,
                                          inv.profound.copy_type,
                                          inv.profound.set_defeat_reward,
                                          now_damage,
                                          finder_id,
                                          finder_name,
                                          inv.id,
                                          inv.profound_id,
                                          inv.deck_idx,
                                          inv.chara_card_dmg_1,
                                          inv.chara_card_dmg_2,
                                          inv.chara_card_dmg_3,
                                          inv.damage_count,
                                          inv.state,
                                          deck_status)
        end
      end
    end

    # 現行渦のハッシュ
    @@playing_prf_hash = nil

    # チェックする渦インベントリ取得
    def get_check_profound_inventory_list
      ProfoundInventory.get_avatar_check_list(id)
    end

    # 渦インベントリ取得
    def get_profound_inventory_list
      ProfoundInventory.get_avatar_battle_list(id)
    end

    # 消滅しているかチェック
    def is_vanished_profound(pi, lt = 0)
      ret = false
      if pi
        if pi.is_not_end?
          # 撃破状態になったのでイベントレコードチェック 2014/06/12
          if pi.is_defeat? && EVENT_PRF_SET_01[0].include?(pi.profound.p_data.id) && pi.score.positive?
            achievement_check(EVENT_PRF_SET_01[1])
          end
        end
        ret = pi.is_vanished?(lt)
      end
      ret
    end

    # 所持渦Inventory数を取得
    def get_prf_inv_num
      ret = 0
      get_profound_inventory_list.each do |pi|
        is_vanish = is_vanished_profound(pi)
        ret += 1 if pi && pi.profound && pi.profound.state != PRF_ST_FINISH && pi.profound.state != PRF_ST_VANISH && !is_vanish
      end
      ret
    end

    # 渦を取得済みか判定
    def is_acquired_profound(hash)
      ProfoundInventory.is_acquired_profound(id, hash)
    end

    # 新規取得渦報告
    def set_new_prf_inv_notice(pi)
      if pi
        profound = pi.profound
        owner = Avatar[profound.found_avatar_id]
        if owner
          prf_name = profound.p_data.name.force_encoding('UTF-8')
          boss_name = profound.p_data.get_boss_name.force_encoding('UTF-8')
          boss_hp = profound.p_data.get_boss_max_hp
          write_notice(NOTICE_TYPE_GET_PROFOUND, [profound.id, owner.name.force_encoding('UTF-8'), prf_name, boss_name, boss_hp].join(','))
        end
        pi.inprogress
      end
    end

    # 新規取得渦の確認
    def new_profound_inventory_check
      get_profound_inventory_list.each do |pi|
        vanished = is_vanished_profound(pi)
        set_new_prf_inv_notice(pi) if pi.is_new? && !vanished
      end
    end

    # 渦をハッシュから取得
    def get_profound_from_hash(hash)
      ret = ERROR_PRF_DATA_NOT_EXIST
      prf = Profound.get_profound_for_hash(hash)
      if prf && prf.server_type == server_type
        if prf.is_vanished?
          ret = ERROR_PRF_FINISHED
        else
          # すでに渦は終了している
          found_avatar = Avatar[prf.found_avatar_id]
          # 発見者のBlackListに入っていたら、取得出来ない
          if FriendLink.is_blocked(found_avatar.player_id, player_id, server_type)
            SERVER_LOG.info("<UID:#{player_id}>DataServer: [#{__method__}] your blocked for profound owner!!! hash:#{hash}")
          else
            owner_name = found_avatar.name
            ret = get_profound(prf, false, owner_name)
          end
        end
      end
      ret
    end

    # 渦を取得する
    def get_profound(profound, owner, _owner_name = nil)
      # 既に所持しているか
      have_prf = ProfoundInventory.get_avatar_profound_for_id(id, profound.id)
      if have_prf
        if have_prf.state == PRF_INV_ST_GIVE_UP
          # ギブアップ済み
          return ERROR_PRF_WAS_GIVE_UP
        else
          # 所持済み
          return ERROR_PRF_ALREADY_HAD
        end
      end
      # 渦が攻略済みの場合取得不可
      if profound.state == PRF_ST_FINISH || profound.state == PRF_ST_VANISH
        return ERROR_PRF_FINISHED
      end
      # 渦の所持数限界を超える場合取得不可
      if get_prf_inv_num >= PROFOUND_MAX
        return ERROR_PRF_HAVE_MAX_OVER
      end

      is_friend = false
      if owner == false
        finder = Avatar[profound.found_avatar_id]
        friends_list = finder ? finder.get_friend_avatar_ids : []
        is_friend = friends_list.include?(id)
      end

      # 渦が人数制限に達している場合取得不可
      if owner == false && is_friend == false && ProfoundInventory.get_profound_avatar_num(profound.id) >= profound.p_data.member_limit
        SERVER_LOG.info("<UID:#{player_id}>RaidServer: [#{__method__}] member limit over!!")
        return ERROR_PRF_MEMBER_LIMIT_OVER
      end
      # inventory作成
      start_score = owner ? profound.p_data.finder_start_point : PRF_JOIN_ADD_SCORE
      inv = ProfoundInventory.get_new_profound_inventory(id, profound.id, owner, start_score)
      ret = inv
      # ランキングデータを初期化
      inv.init_ranking

      # 各情報を送信
      if owner
        resend_profound_inventory(nil, false)
        # 渦取得レコード
        if FIND_PROFOUND_01[0].include?(profound.p_data.id)
          achievement_check(FIND_PROFOUND_01[1])
        end
        if FIND_PROFOUND_02[0].include?(profound.p_data.id)
          achievement_check(FIND_PROFOUND_02[1])
        end
        # 現行渦IDHashに追加
        @@playing_prf_hash = CACHE.get('playing_prf_hash')
        if @@playing_prf_hash
          playing_prf_hash[profound.id] = id
          CACHE.set('playing_prf_hash', @@playing_prf_hash, PRF_PLAYING_HASH_CACHE_TTL)
        end
      end
      ret
    end

    # 友達にも渦を追加する
    def send_profound_friends(profound)
      links = FriendLink.get_link(player_id, server_type)
      links.each do |a|
        if a.friend_type == FriendLink::TYPE_FRIEND
          other_player = Player[a.other_id(player_id)]
          other_avatar = other_player.current_avatar if other_player
          if other_avatar
            list = CACHE.get("get_friend_prf:#{other_avatar.id}")
            list ||= []
            list << profound.id
            CACHE.set("get_friend_prf:#{other_avatar.id}", list, 60 * 60 * 24)
          end
        end
      end
      Time.now
    end

    # フレンドのアバターID一覧を取得
    def get_friend_avatar_ids
      links = FriendLink.get_link(player_id, server_type)
      ids = []
      links.each do |a|
        if a.friend_type == FriendLink::TYPE_FRIEND
          other_player = Player[a.other_id(player_id)]
          other_avatar = other_player.current_avatar if other_player
          ids << other_avatar.id
        end
      end
      ids
    end

    # 渦の消滅判定
    def profound_vanish_check(prf_inv)
      if prf_inv && prf_inv.avatar_id == id
        prv_st = prf_inv.state
        vanished = is_vanished_profound(prf_inv)
        new_st = prf_inv.state
        unless vanished
          if prv_st != new_st && (prv_st != PRF_INV_ST_SOLVED && prv_st != PRF_INV_ST_FAILED) && [PRF_INV_ST_SOLVED, PRF_INV_ST_FAILED].include?(new_st)
            if new_st == PRF_INV_ST_FAILED
              prf_name = prf_inv.profound.p_data.name.force_encoding('UTF-8')
              boss_name = prf_inv.profound.p_data.get_boss_name.force_encoding('UTF-8')
              write_notice(NOTICE_TYPE_FIN_PRF_FAILED, [prf_inv.profound.id, prf_name, boss_name].join(','))
            else
              send_prf_info(prf_inv)
            end
          end
        end

        send_prf_info(prf_inv)
      end
    end

    # 渦バトルに必要なものを用意
    def profound_start_set_up(inv_id, use_ap)
      ret = 0

      inv = ProfoundInventory[inv_id]
      # 渦インベントリが存在するか？
      unless inv && inv.avatar_id == id
        ret = ERROR_PRF_INV_IS_NONE
        return ret
      end

      prf = inv.profound
      # 渦情報が存在するか？
      unless prf
        ret = ERROR_PRF_NOT_EXIST
        return ret
      end

      # 消滅していないか
      if is_vanished_profound(inv)
        ret = ERROR_PRF_FINISHED
        return ret
      end

      # 撃破済みか
      if inv.profound.is_finished?
        ret = ERROR_PRF_FINISHED
        return ret
      end

      prf_data = prf.p_data
      # 渦データが存在するか
      unless prf_data
        ret = ERROR_PRF_DATA_NOT_EXIST
        return ret
      end

      boss_deck = AI.chara_card_deck(prf_data.core_monster_id)
      # Bossのデッキ情報があるか
      unless boss_deck && !boss_deck.card_inventories.empty?
        ret = ERROR_PRF_BOSS_NOT_EXIST
        return ret
      end

      # APが十分か？
      unless  check_energy(use_ap)
        ret = ERROR_AP_LACK
        return ret
      end

      # デッキにカードがセットされているか
      if duel_deck.card_inventories.empty?
        ret = ERROR_NOT_EXIST_CHARA
        return ret
      end

      # ログ表示などの為に、Bossの名前を保持しておく
      boss_name = boss_deck.card_inventories.map do |ci|
        ci.chara_card.name
      end

      set_data = {
        inv:,
        data: prf_data,
        boss_deck:,
        deck_idx: current_deck,
        avatar_deck: duel_deck,
        stage: prf_data.stage,
        boss_name:
      }

      [ret, set_data]
    end

    # 渦戦闘開始処理
    def profound_duel_start(inv, use_ap, _deck_idx)
      # 渦戦闘回数レコード
      check_raid_btl_cnt_record(inv.profound.p_data.id) if inv.btl_count <= 0

      # 戦闘回数を加算
      inv.update_battle_count
      # ランキングデータ操作の為、初期化
      inv.init_ranking
      # Scoreが0なら1加算
      inv.update_score(1) if inv.score.zero?
      # AP消費
      energy_use(use_ap)
      # refresh # 必要ない。energy_use内でやってるから
      send_prf_info(inv, false)
    end

    # レイド戦参加カウントレコードチェック
    def check_raid_btl_cnt_record(prf_data_id)
      # 特定の渦限定チェック
      if RAID_BTL_CNT_01[0].include?(prf_data_id)
        achievement_check(RAID_BTL_CNT_01[1])
      end
      if RAID_BTL_CNT_02[0].include?(prf_data_id)
        achievement_check(RAID_BTL_CNT_02[1])
      end
      # 指定渦なしのカウントチェック
      achievement_check(RAID_BTL_CNT_03)
      # 非限定チェック
      achievement_check(ALL_RAID_BTL_CNT_IDS)
    end

    # 渦戦闘終了
    def profound_duel_finish(inv, give_up = false)
      ret = 0

      # 渦インベントリが存在するか？
      unless inv && inv.avatar_id == id
        ret = ERROR_PRF_INV_IS_NONE
        return ret
      end

      # 渦インベントリを失敗状態に変更
      if give_up
        inv.give_up
      end
      ret
    end

    def get_treasures(genr, id, type = 0, num = 1, weapon_record_check = true)
      # By_K2 (achievement/profound GEM支給の不具合の修正)
      if genr == TG_GEM && id.zero?
        id = num
      end

      ret = 0

      case genr
      when TG_NONE
      when TG_CHARA_CARD
        num.times do |_i|
          get_chara_card(id)
        end
      when TG_SLOT_CARD
        num.times do |_i|
          get_slot_card(type, id, weapon_record_check)
        end
      when TG_AVATAR_ITEM
        num.times do |_i|
          get_item(id)
        end
      when TG_AVATAR_PART
        # すでにもっているならノーティスを出さない
        if parts_dupe_check(id)
          ret = ERROR_PARTS_DUPE
        else
          num.times do |_i|
            get_part(id, true)
          end
        end
      when TG_GEM
        set_gems(id)
      when TG_OWN_CARD
        get_card_lv = id
        get_own_card(get_card_lv, num)
      end
      ret
    end

    # By_K2 (BP 1600 이상시 무한의탑 기간제 티켓 지급)
    def get_login_tower_bonus
      trs = TOWER_LOGIN_BONUS
      get_treasures(trs[0], trs[2], trs[1])
      trs
    end

    # 復活後名前が変わったひと
    RENAME_CHARACTORS = [9]
    # デッキの先頭のカードについて、Lvを指定しnum枚入手
    def get_own_card(lv, num)
      vid = get_own_vanguard_card_id
      van_card = CharaCard[vid]
      if van_card
        cid = van_card.kind == CC_KIND_CHARA ? van_card.charactor_id : van_card.base_charactor_id
        cname = RENAME_CHARACTORS.include?(cid) ? Charactor[cid].name : van_card.name
        own_card = CharaCard.filter([[:name, cname], [:level, lv], [:rarity, 1..5], [:charactor_id, cid]]).first
        unless own_card.nil?
          num.times do |_i|
            get_chara_card(own_card.id)
            get_quest_treasure_event(TG_OWN_CARD, TG_CHARA_CARD, own_card.id)
          end
        end
      end
    end

    # 先頭キャラのIDを返す
    # レンタルカードの場合は2枚目以降を調べる
    def get_own_vanguard_card_id
      van_id = 0
      duel_deck.cards.each do |c|
        case c.kind
        when CC_KIND_CHARA, CC_KIND_REBORN_CHARA, CC_KIND_EPISODE
          van_id = c.id
          break
        when CC_KIND_RENTAL
          next
        else
          van_id = 1
        end
      end
      van_id = get_gem_man_id if van_id.zero?
      van_id
    end

    # gem男をランダムに選ぶ
    def get_gem_man_id
      rand(5) * 10 + 1
    end

    # ログインボーナスを取得
    def get_login_bonus
      trs = []

      if EVENT_LOGIN_BONUS_FLAG
        trs = EVENT_LOGIN_BONUS
      else
        trs << LOGIN_BONUS_ITEM.sample
      end

      if PLUS_EVENT_LOGIN_BONUS_FLAG
        trs << EVENT_LOGIN_BONUS
      end

      trs.each do |t|
        get_treasures(t[0], t[2], t[1], t[3])
      end
      trs
    end

    # 同じパーツIDがあるか？
    def parts_dupe_check(parts_id)
      ret = false
      refresh
      part_inventories.each do |pi|
        if pi.avatar_part_id == parts_id
          ret = true
          break
        end
      end
      ret
    end

    # クジを引く
    def draw_lot(kind)
      ret = []
      if LOT_TIKECT_NUM[kind]
        if use_ticket(LOT_TIKECT_NUM[kind])
          a_lot = RareCardLot.draw_lot(kind)
          b_lot = RareCardLot.draw_lot(kind)
          c_lot = RareCardLot.draw_lot(kind)
          # もしアタリがパーツでかつ所持済みならば弾き直す
          a_lot = RareCardLot.draw_lot(kind) while a_lot.article_kind == SHOP_PART && parts_dupe_check(a_lot.article_id)
          num = 1
          num = a_lot.num if a_lot.num
          case a_lot.article_kind
          when SHOP_ITEM
            num.times do
              get_item(a_lot.article_id)
            end
          when SHOP_PART
            get_part(a_lot.article_id)
          when SHOP_EVENT_CARD
            num.times do
              get_slot_card(SCT_EVENT, a_lot.article_id)
            end
          when SHOP_WEAPON_CARD
            num.times do
              get_slot_card(SCT_WEAPON, a_lot.article_id)
            end
          when SHOP_CHARA_CARD
            num.times do
              get_chara_card(a_lot.article_id)
            end
          end
          ret = [a_lot, b_lot, c_lot]
        end
      end
      ret
    end

    # カードを複製する
    def copy_card(id)
      ret = false
      c = CharaCard[id]
      if !cards_list.index(id).nil? && c && c.rarity < 6 && use_copy_tickets
        get_chara_card(id)
        ret = true
      end
      ret
    end

    # チケットを特定枚数つかう
    def use_ticket(num)
      ret = false
      counter = 0
      t = tickets
      if t.size >= num
        t.each do |s|
          s.use(self)
          @event.item_use_event(s.id) if @event
          counter += 1
          break if counter >= num
        end
        ret = true
      end
      ret
    end

    # チケットを特定枚数つかう
    def use_copy_tickets
      ticket = copy_tickets.first
      return false if ticket.nil?

      ticket.use(self)
      @event.item_use_event(ticket.id) if @event
      true
    end

    # コインを消費する
    def use_coin(uses)
      ret = []
      # 各カードの枚数を格納するハッシュ
      nums = Hash.new { |hash, key| hash[key] = [] }
      # バインダーに入ったカードを種類ごとに枚数を列挙する
      binder.card_inventories.each { |c| nums[c.chara_card_id] << c }
      uses.each_index do |i|
        if i >= (TIPS_CARD_ID - COIN_CARD_ID)
          cid = EX_COIN_CARD_ID
        else
          cid = (COIN_CARD_ID + i).to_i
        end
        uses[i].times do |_c|
          ret << nums[cid].last.id
          nums[cid].pop.delete_from_deck
        end
      end
      @event.coin_use_event(ret) if @event
      ret
    end

    # 指定したアイテムを購入する
    def buy_item(shop_id, item_id, amount = 1)
      refresh
      ret = Shop.buy_article(shop_id, SHOP_ITEM, item_id, self.gems, coins, amount)
      if ret[0]
        amount.times do |_c|
          get_item(item_id)
        end
        use_coin(ret[1])
        self.gems = ret[0]
        save_changes
        @event.update_gems_event if @event
      end
      ret[0]
    end

    # 指定したスロットカードを購入する
    def buy_slot_card(shop_id, sct_type, card_id, amount = 1)
      ret = [false, []]
      ntype = sct_type - 1 # 正規化したタイプ
      case ntype
      when SCT_EVENT
        ret = Shop.buy_article(shop_id, SHOP_EVENT_CARD, card_id, self.gems, coins, amount)
      when SCT_WEAPON
        ret = Shop.buy_article(shop_id, SHOP_WEAPON_CARD, card_id, self.gems, coins, amount)
      end
      if ret[0]
        refresh
        amount.times do |_c|
          get_slot_card(ntype, card_id)
        end
        use_coin(ret[1])
        self.gems = ret[0]
        save_changes
        @event.update_gems_event if @event
      end
      ret[0]
    end

    # 指定したキャラカードを購入する
    def buy_chara_card(shop_id, card_id, amount = 1)
      # 買えるショップか調べる
      ret = Shop.buy_article(shop_id, SHOP_CHARA_CARD, card_id, self.gems, coins, amount)
      if ret[0]
        refresh
        amount.times do |_c|
          get_chara_card(card_id)
        end
        use_coin(ret[1])
        self.gems = ret[0]
        save_changes
        @event.update_gems_event if @event
      end
      ret[0]
    end

    # 指定したキャラカードを購入する
    def buy_part(shop_id, part_id)
      ret = [0, 0, []]
      if parts_dupe_check(part_id)
        ret =  ERROR_PARTS_DUPE
        return ret
      end
      # 買えるショップか調べる
      result = Shop.buy_article(shop_id, SHOP_PART, part_id, self.gems, coins)
      if result[0]
        refresh
        get_part(part_id)
        use_coin(result[1])
        self.gems = result[0]
        save_changes
        @event.update_gems_event if @event
        ret = 0
      else
        ret = ERROR_GEM_DEFICIT
      end
      ret
    end

    # ペイメントログ、アイテムを含めたデッキ数を取得
    def get_all_deck_num_include_payment_log
      now_decks_num = decks_num
      p_logs = PaymentLog.filter({ player_id:, result: PaymentLog::STATE_PAYED }).filter([[:real_money_item_id, RM_ITEM_DECK_ID]]).all
      deck_items = ItemInventory.where(avatar_id: id, avatar_item_id: DECK_ITEM_ID, state: ITEM_STATE_NOT_USE).all
      add_num = 0
      p_logs.each { |plog| add_num += plog.num }
      add_num += deck_items.size unless deck_items.empty?
      now_decks_num + add_num
    end

    # 課金アイテムを付与する
    def get_real_money_item
      # 自分の支払い済みのログを探し出す
      p_log_set = PaymentLog.filter({ player_id:, result: PaymentLog::STATE_PAYED }).all
      ret = []
      # ログに支払いがあるとき
      if p_log_set && p_log_set.count.positive?
        PaymentLog.db.transaction do
          # それぞれのログに対して
          p_log_set.each do |p_log|
            # 念のためリフレッシュして
            # tableをLOCK
            p_log.lock!
            p_log.refresh
            # すでにアイテムを渡していたら抜ける
            unless p_log.result == PaymentLog::STATE_END
              # アイテム付与済みにする
              p_log.item_got
              # 個数分の
              p_log.num.times do
                # リアルアイテムを付与する
                real_money_item_to_item(p_log.real_money_item)
              end
              ret.push({ payment_id: p_log.id, rm_item_id: p_log.real_money_item_id, num: p_log.num })
            end
          end
        end
      end
      ret
    end

    # リアルマネーアイテムからアイテムへ数を変換してゲットさせる
    def real_money_item_to_item(rmi)
      if rmi
        case rmi.rm_item_type
        when RMI_TYPE_ITEM
          rmi.num.times { get_item(rmi.item_id) }
        when RMI_TYPE_PARTS
          rmi.num.times { get_part(rmi.item_id, true) }
        when RMI_TYPE_EVENT_CARD
          rmi.num.times { get_slot_card(SCT_EVENT, rmi.item_id) }
        when RMI_TYPE_WEAPON_CARD
          rmi.num.times { get_slot_card(SCT_WEAPON, rmi.item_id) }
        when RMI_TYPE_CHARA_CARD
          rmi.num.times { get_chara_card(rmi.item_id) }
        when RMI_TYPE_DECK
          list = real_money_deck_set_all_cards(rmi)
          rmi.num.times { create_deck(rmi.item_id, list) }
          return # デッキの場合のみ自前でセット販売を終わらせる（デッキに詰め込む必要があるため）
        end
        # セット販売があるときはそいつも追加()
        if rmi.extra_id != 0
          r = RealMoneyItem[rmi.extra_id]
          real_money_item_to_item(r) if r
        end
      end
    end

    # デッキを買った場合、セットで買ったカードはそのデッキに入る
    def real_money_deck_set_all_cards(rmi, list = [])
      if rmi
        case rmi.rm_item_type
        when RMI_TYPE_EVENT_CARD
          rmi.num.times do
            inv = get_slot_card(SCT_EVENT, rmi.item_id)
            list << { type: RMI_TYPE_EVENT_CARD, inv: }
          end
        when RMI_TYPE_WEAPON_CARD
          rmi.num.times do
            inv = get_slot_card(SCT_WEAPON, rmi.item_id)
            list << { type: RMI_TYPE_WEAPON_CARD, inv: }
          end
        when RMI_TYPE_CHARA_CARD
          rmi.num.times do
            inv = get_chara_card(rmi.item_id)
            list << { type: RMI_TYPE_CHARA_CARD, inv: }
          end
        end
        # セット販売があるときはそいつも追加()
        if rmi.extra_id != 0
          r = RealMoneyItem[rmi.extra_id]
          list = real_money_deck_set_all_cards(r, list) if r
        end
        list
      end
    end

    def resend_quest_inventory
      avatar_quest_inventories.each do |aqi|
        unless aqi.status == QS_PENDING
          if aqi.before_avatar_id.zero? || aqi.before_avatar_id.nil?
            ba_name = QUEST_PRESENT_AVATAR_NAME_NIL
          elsif defined?(Avatar[aqi.before_avatar_id].name)
            ba_name = Avatar[aqi.before_avatar_id].name.force_encoding('UTF-8')
          else
            ba_name = QUEST_PRESENT_AVATAR_NAME_NIL
          end
          @event.quest_get_event(aqi.id, aqi.quest_id, 0, 100, aqi.status, ba_name) if @event
        end
      end
    end

    def new_profound_check
      ret = []
      # キャッシュにない場合
      unless @@playing_prf_hash
        # 現在進行中の渦リストを取得
        prf_list = Profound.get_playing_prf(player.server_type)
        @@playing_prf_hash = {}
        prf_list.each do |prf|
          @@playing_prf_hash[prf.id] = prf.found_avatar_id
        end
      end
      # FriendLinkからフレンド一覧を取得
      links = FriendLink.get_link(player_id, server_type)
      friend_pl_ids = []
      links.each do |a|
        if a.friend_type == FriendLink::TYPE_FRIEND
          friend_pl_ids << a.other_id(player_id)
        end
      end
      # フレンド一覧から渦の最大時間以内にログインしているユーザーのみを抽出
      login_at_border = Time.now.utc - ProfoundData.get_max_ttl
      # SQLで必要なものを一気に取得
      return ret if friend_pl_ids.size <= 0

      sql = "SELECT avatars.id,avatars.name FROM avatars INNER JOIN players ON avatars.player_id=players.id WHERE avatars.player_id IN (#{friend_pl_ids.join(',')}) AND players.login_at > '#{login_at_border.strftime('%Y-%m-%d %H:%M:%S')}'"
      avatars_tmp = DB.fetch(sql).all
      return ret if avatars_tmp.nil? || avatars_tmp.size <= 0

      check_avatars = {}
      check_avatar_ids = []
      avatars_tmp.each do |ava|
        check_avatars[ava[:id]] = ava
        check_avatar_ids << ava[:id]
      end
      add_prf_list = [] # 追加渦リスト
      delete_id_list = [] # 現在進行中の渦IDHashから削除するIDリスト
      # 現在進行中の渦Hashからフレンドが発見した渦を捜索
      @@playing_prf_hash.each do |prf_id, found_avatar_id|
        if check_avatar_ids.include?(found_avatar_id)
          prf = Profound[prf_id]
          # 渦が継続中か再確認
          if prf && prf.is_finished? == false
            add_prf_list << prf
          else
            # 終了していたので、削除リストに追加
            delete_id_list << prf_id
          end
        end
      end
      # 先に削除リストから現行渦IDHashを更新する
      @@playing_prf_hash = CACHE.get('playing_prf_hash') # 念のため再取得
      if @@playing_prf_hash
        @@playing_prf_hash.reject! { |key, _val| delete_id_list.include?(key) }
        CACHE.set('playing_prf_hash', @@playing_prf_hash, PRF_PLAYING_HASH_CACHE_TTL)
      end
      # 発見者IDリストからAvatarを取得
      add_prf_list.each do |prf|
        if check_avatars[prf.found_avatar_id]
          get_profound(prf, false, check_avatars[prf.found_avatar_id][:name])
          ret << prf.id
        end
      end
      ret
    end

    def resend_profound_inventory(check_list = nil, r = true)
      get_check_profound_inventory_list.each do |pi|
        vanished = is_vanished_profound(pi)
        check_profound_reward(pi, r)
        set_new_prf_inv_notice(pi) if pi.is_new? && !vanished
        if vanished == false && (check_list.nil? || check_list.index(pi.profound_id))
          send_prf_info(pi, false)
        end
      end
      @event.resend_profound_inventory_finish_event if @event
    end

    # 渦報酬取得
    def check_profound_reward(inv, r = true)
      ret = false # 報酬配布を行ったか
      if inv
        # 報酬取得可能か判定
        if inv.check_get_reward(r)
          # 念の為、ランキング初期化
          inv.init_ranking
          # 報酬取得可能の場合、付与
          inv.get_reward(self, r)
          # リザルトの内容があれば、投げる
          inv.set_btl_result_notice(self, false)
          ret = true
        end
      end
      ret
    end

    # マップIDから通常のかイベント用のかを判定しフラグを返す
    def get_quest_flag(quest_map_id)
      ret = 0
      if quest_map_id < QUEST_TUTORIAL_MAP_START
        ret = quest_flag
      elsif quest_map_id < QUEST_EVENT_MAP_START
        eqf_inv = get_event_quest_flag_inventory(QUEST_TUTORIAL_ID)
        ret = eqf_inv.quest_flag
      elsif quest_map_id < QUEST_CHARA_VOTE_MAP_START
        eqf_inv = get_event_quest_flag_inventory
        ret = eqf_inv.quest_flag
      else
        eqf_inv = get_event_quest_flag_inventory(QUEST_CHARA_VOTE_ID)
        ret = eqf_inv.quest_flag
      end
      ret
    end

    # マップIDから通常のかイベント用のかを判定し進行度を返す
    def get_quest_clear_num(quest_map_id)
      ret = 0
      if quest_map_id < QUEST_TUTORIAL_MAP_START
        ret = quest_clear_num
      elsif quest_map_id < QUEST_EVENT_MAP_START
        eqf_inv = get_event_quest_flag_inventory(QUEST_TUTORIAL_ID)
        ret = eqf_inv.quest_clear_num
      elsif quest_map_id < QUEST_CHARA_VOTE_MAP_START
        eqf_inv = get_event_quest_flag_inventory
        ret = eqf_inv.quest_clear_num
      else
        eqf_inv = get_event_quest_flag_inventory(QUEST_CHARA_VOTE_ID)
        ret = eqf_inv.quest_clear_num
      end
      ret
    end

    # 指定した場所のクエストを取得する
    def get_quest(quest_map_id, timer = 0)
      ret = 0
      # クエストマップが存在するか？
      unless QuestMap[quest_map_id]
        ret = ERROR_WRONG_QUEST_MAP_NO
        return ret
      end
      # APが十分か？
      unless  check_energy(QuestMap[quest_map_id].ap)
        ret = ERROR_AP_LACK
        return ret
      end

      # MAX数に達しているか？
      if quest_inventory_capacity?
        # プレゼントがあったら再送する
        resend_quest_inventory
        ret = ERROR_MAX_QUEST
        return ret
      end

      # クエストマップに合わせたフラグと進行度を取得
      flag = get_quest_flag(quest_map_id)
      clear_num = get_quest_clear_num(quest_map_id)

      # クエストの進捗をチェックする
      if flag + 1 < quest_map_id
        ret = ERROR_NOT_ENOUGH_LEVEL
        return ret
      end

      is_cleared_map = flag >= quest_map_id
      if timer.zero?
        # クエストインベントリをすぐに追加
        inv = AvatarQuestInventory.new do |i|
          i.avatar_id = id
          i.quest_id = QuestMap[quest_map_id].get_quest_id(clear_num, 0, is_cleared_map)
          i.status = QS_NEW
          i.save_changes
        end
        inv ||= AvatarQuestInventory.new do |i|
          i.avatar_id = id
          i.quest_id = QuestMap[quest_map_id].get_quest_id(clear_num, 0, is_cleared_map)
          i.status = QS_NEW
          i.save_changes
        end
        energy_use(QuestMap[quest_map_id].ap)
        @event.quest_get_event(inv.id, inv.quest_id, 0) if @event
      else
        f_pow = get_quest_find_pow
        # クエストインベントリをpendingで追加
        inv = AvatarQuestInventory.new do |i|
          i.avatar_id = id
          i.quest_id = QuestMap[quest_map_id].get_quest_id(clear_num, timer, is_cleared_map)
          i.set_find_time(timer, f_pow)
          i.status = QS_PENDING
          i.save_changes
        end
        # 気持ち悪いがなぜかとれない時があるので。ループにしないのは怖いから
        inv ||= AvatarQuestInventory.new do |i|
          i.avatar_id = id
          i.quest_id = QuestMap[quest_map_id].get_quest_id(clear_num, timer, is_cleared_map)
          i.set_find_time(timer, f_pow)
          i.status = QS_PENDING
          i.save_changes
        end
        @event.quest_get_event(inv.id, 0, timer, f_pow, QS_NEW, QUEST_PRESENT_AVATAR_NAME_NIL) if @event
        energy_use(QuestMap[quest_map_id].ap) # AP消費はTimer分消費
      end
      ret
    end

    # 指定した場所のEXクエストを取得する
    def get_ex_quest(quest_map_id, timer = 0)
      ret = 0
      # クエストマップに合わせた進行度を取得
      clear_num = get_quest_clear_num(quest_map_id)
      if timer.zero?
        # クエストインベントリをすぐに追加
        inv = AvatarQuestInventory.new do |i|
          i.avatar_id = id
          i.quest_id = QuestMap[quest_map_id].get_quest_id(clear_num)
          i.status = QS_NEW
          i.save_changes
        end
        @event.quest_get_event(inv.id, inv.quest_id, 0) if @event
      else
        f_pow = get_quest_find_pow
        # クエストインベントリをpendingで追加
        inv = AvatarQuestInventory.new do |i|
          i.avatar_id = id
          i.quest_id = QuestMap[quest_map_id].get_quest_id(clear_num, timer)
          i.set_find_time(timer, f_pow)
          i.status = QS_PENDING
          i.save_changes
        end
        @event.quest_get_event(inv.id, 0, timer, f_pow, QS_NEW, QUEST_PRESENT_AVATAR_NAME_NIL) if @event
      end
      ret
    end

    # 現在の地域のボスクエストを取得する
    def get_boss_quest(quest_map_no)
      ret = 0
      get_boss_map = 0
      now_area_map_list = nil
      quest_type = QUEST_TYPE_NORMAL
      if quest_map_no < QUEST_TUTORIAL_MAP_START
        quest_type = QUEST_TYPE_NORMAL
      elsif quest_map_no < QUEST_EVENT_MAP_START
        quest_type = QUEST_TYPE_TUTORIAL
      elsif quest_map_no < QUEST_CHARA_VOTE_MAP_START
        quest_type = QUEST_TYPE_EVENT
      else
        quest_type = QUEST_TYPE_CHARA_VOTE
      end
      QUEST_AREA_MAP_LIST[quest_type].each do |map_no_list|
        if map_no_list.include?(quest_map_no)
          now_area_map_list = map_no_list
          break
        end
      end
      now_quest_flag = get_quest_flag(quest_map_no)
      if now_quest_flag > quest_map_no
        # 現在エリアからランダム取得
        get_boss_map = now_area_map_list.sample + 1
      else
        if quest_clear_capaciry?(quest_map_no)
          get_boss_map = now_quest_flag + 1
        else
          ret = ERROR_ITEM_NOT_BOSS_FLAG
        end
      end

      if get_boss_map.positive?
        boss_quest_id = QuestMap[get_boss_map].get_boss_quest_id
        if boss_quest_id != 1
          # クエストインベントリをすぐに追加
          inv = AvatarQuestInventory.new do |i|
            i.avatar_id = id
            i.quest_id = boss_quest_id
            i.status = QS_NEW
            i.save_changes
          end
          @event.quest_get_event(inv.id, inv.quest_id, 0) if @event
        end
      end
      ret
    end

    # 指定した場所のクエストを取得する
    def check_find_quest(quest_inv_id)
      inv = AvatarQuestInventory[quest_inv_id]
      # インベントリが存在してかつ自分が所持者の時
      if inv && inv.avatar_id == id
        if inv.quest_find?
          @event.quest_state_update_event(quest_inv_id, inv.status, inv.quest_id) if @event
        end
      end
    end

    # 探索中のクエストがありますか？
    def quest_pending?
      ret = false
      refresh
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_PENDING
          ret = true
          break
        end
      end
      ret
    end

    # 所持クエストの時間を進ませる
    def quest_time_go(min)
      ret = -1
      # 所持クエストのうち、状態が探索中のものの探索時間を短くする
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_PENDING
          aqi.shorten_find_time(min)
          now = Time.now.utc
          t = (aqi.find_at - now).to_i
          @event.quest_find_at_update_event(aqi.id, t) if @event
          ret = 0
        end
      end
      ret
    end

    # アバターのイベント初期化
    def init
      @event = AvatarEvent.new(self)
    end

    def respond_to_missing?(*)
      @event.respond_to?(*)
    end

    # イベントを委譲する
    def method_missing(message, *)
      @event.send(message, *)
    end

    # 報酬ゲームオブジェの保存と結果の保存
    def set_reward(r, is_get_bp = 0, channel_rule = CRULE_FREE)
      r.set_avatar(self)
      r.set_deck_exp_pow(RADDER_DUEL_DECK_EXP_POW) if is_get_bp != 0
      r.set_card_bonus_pow(RADDER_DUEL_CARD_BONUS_POW) if is_get_bp != 0
      r.set_channel_rule(channel_rule)
      @reward = r
    end

    # 報酬ゲームオブジェの参照
    def get_reward
      @reward
    end

    # クエストの状態を更新する
    def update_quest_state(inv, state, deck_index)
      # インベントリが存在してかつ自分が所持者の時
      if inv && inv.avatar_id == id
        # 今のステータスと新しいステータスが違い、かつ変更可能な遷移なら変更する(Stateは減らない)
        if inv.status < state || inv.status == QS_PRESENTED
          inv.status = state
          inv.deck_index = deck_index unless deck_index.zero?
          inv.save_changes
          @event.quest_state_update_event(inv.id, inv.status, inv.quest_id) if @event
        end
      end
    end

    # クエストを消去する
    def quest_delete(inv, win)
      # インベントリが存在してかつ自分が所持者の時
      if inv && inv.avatar_id == id
        # 勝利していたら
        if win
          record_check = false
          # 進行中の地域ならば
          if inv.quest.quest_map_id == get_quest_flag(inv.quest.quest_map_id) + 1
            # もしボス戦を勝っていたら、フラグを更新する
            if quest_clear_capaciry?(inv.quest.quest_map_id) && inv.quest.kind == QT_BOSS
              quest_map_clear(inv.quest.quest_map_id)
            else
              # クリア値を1ポイントインクリメントする
              update_quest_clear_num(1, inv.quest.quest_map_id)
            end
            record_check = true
          # クリア済みなら
          elsif !quest_flag_capaciry?(inv.quest.quest_map_id)
            # 通常マップならそのまま、特殊マップなら通常マップがクリア済みか判定
            if QUEST_TUTORIAL_MAP_START > inv.quest.quest_map_id
              record_check = true
            elsif !quest_flag_capaciry?(QUEST_CAP)
              record_check = true
            end
          end

          # 週間レコードクリアチェック (クエストが進行or最終地のクエストをクリア)
          week_record_clear_check(WEEK_QUEST_ACHIEVEMENT_IDS) if record_check

          # もらったクエストならば相手にプレゼントを渡す
          if inv.presented?
            ba = Avatar[inv.before_avatar_id]
            # 相手が存在するなら
            if ba
              bonus = SEND_QUEST_BONUS[inv.quest.rarity]
              # ボーナスが存在するなら
              if bonus
                item_array = []
                item_array << name
                if bonus[:TG_GEM]
                  SERVER_LOG.info("<UID:#{player_id}>Avatar: delete quest, add present bonus,avatar_id:#{ba.id},bonus:#{bonus[:TG_GEM]}GEM")
                  ba.set_gems(bonus[:TG_GEM])
                  item_array << TG_GEM
                  item_array << 0
                  item_array << bonus[:TG_GEM]
                end
                # お知らせにも追記
                ba.write_notice(NOTICE_TYPE_QUEST_SUCC, item_array.join(','))
              end
            end
          end
          save_changes
        end
        inv.clear_all(win)
        avatar_quest_inventories.delete(inv)
        @event.quest_deleted_event(inv.id) if @event
      end
      refresh
    end

    # クエストをスタートする
    def quest_start(id, deck_index)
      inv = AvatarQuestInventory[id]
      ret = 0
      # クエストインベントリが存在するか？
      unless inv && inv.avatar_id == self.id
        ret = ERROR_QUEST_INV_IS_NONE
        return ret
      end
      # APが十分か？
      unless  check_energy(inv.quest.ap)
        ret = ERROR_AP_LACK
        return ret
      end
      # インベントリは攻略可能か
      unless inv.unsolved?
        ret = ERROR_QUEST_STATUS_WRONG
        return ret
      end

      # バインダーではなく、きちんとデッキは存在するか
      unless deck_index != 0 && chara_card_decks[deck_index]
        ret = ERROR_NOT_EXIST_DECK
        return ret
      end

      # デッキはクエスト可能か
      unless chara_card_decks[deck_index].status == CDS_NONE
        ret = ERROR_DECK_IS_ALREADY_QUESTED
        return ret
      end

      SERVER_LOG.info("<UID:#{player_id}>Avatar: quest start:id#{inv.id}, inv quest:id,#{inv.quest.id}")
      energy_use(inv.quest.ap)
      update_quest_state(inv, QS_INPROGRESS, deck_index)
      chara_card_decks[deck_index].status = CDS_QUEST
      chara_card_decks[deck_index].save_changes
      ret
    end

    # クエストを進行させる
    def next_land(inv, deck_index, current_no, next_no)
      ret = 0

      # クエストインベントリが存在するか？
      unless inv && inv.avatar_id == id
        ret = ERROR_QUEST_INV_IS_NONE
        return ret
      end

      # インベントリは攻略可能か
      unless inv.status == QS_INPROGRESS
        ret = ERROR_QUEST_STATUS_WRONG
        return ret
      end

      # バインダーではなく、きちんとデッキは存在するか
      unless deck_index != 0 && chara_card_decks[deck_index]
        ret = ERROR_NOT_EXIST_DECK
        return ret
      end

      # デッキはクエスト中か
      unless chara_card_decks[deck_index].status == CDS_QUEST
        ret = ERROR_DECK_IS_ALREADY_QUESTED
        return ret
      end

      # そのランドに到達出来るか？
      unless inv.quest && inv.quest.check_road_exist?(current_no, next_no)
        ret =  ERROR_NEXT_QUEST_LAMD_WRONG
        return ret
      end

      update_quest_state(inv, QS_INPROGRESS, deck_index)
      chara_card_decks[deck_index].status = CDS_QUEST
      chara_card_decks[deck_index].save_changes
      ret
    end

    # 地形のステージを引いてくる
    def get_land_enemy(id, next_no)
      inv = AvatarQuestInventory[id]
      inv.quest.get_position_enemy(next_no) if inv && inv.quest
    end

    # 地形の宝箱を引いてくる
    def get_land_treasure(inv, next_no)
      inv.quest.get_position_treasure(next_no) if inv && inv.quest
    end

    # 地形のステージを引いてくる
    def get_land_stage(inv, next_no)
      inv.quest.get_position_stage(next_no) if inv && inv.quest
    end

    # 地形のクエストボーナスレベルを引いてくる
    def get_treasure_bonus_level(inv, next_no)
      ret = 0
      ret = inv.quest.get_position_bonus_level(next_no) if inv && inv.quest
      ret
    end

    # クエストインベントリのダメージを取得する
    def get_damage_set(inv)
      inv.get_damage_set
    end

    # クエストインベントリのダメージを保存する
    def set_damage_set(inv, damage_set)
      inv.set_damage_set(damage_set) if inv
      @event.quest_deck_state_update_event(inv.deck_index, inv.status, inv.hp0, inv.hp1, inv.hp2) if @event && inv
    end

    # 地形を攻略した
    def land_clear(inv, land_no)
      # クエストインベントリが存在するか？
      unless inv && inv.avatar_id == id
        ret = ERROR_QUEST_INV_IS_NONE
        return ret
      end
      # もしくりあしていなかったらクリアしてイベントを発射
      unless inv.land_cleared?(land_no)
        inv.clear_land(land_no)
        @event.quest_progress_update_event(inv.id, inv.progress) if @event
        # ここで宝箱を渡す
        if get_land_treasure(inv, land_no) != 0
          td = TreasureData[get_land_treasure(inv, land_no)]
          if td
            # By_K2 (무한의탑 10층 단위로 층별 변경보상)
            if inv.quest.quest_map_id == QM_EV_INFINITE_TOWER
              case floor_count
              when 71
                trs = TOWER_FLOOR_71_REWARD
              when 61
                trs = TOWER_FLOOR_61_REWARD
              when 51
                trs = TOWER_FLOOR_51_REWARD
              when 41
                trs = TOWER_FLOOR_41_REWARD
              when 31
                trs = TOWER_FLOOR_31_REWARD
              when 21
                trs = TOWER_FLOOR_21_REWARD
              when 11
                trs = TOWER_FLOOR_11_REWARD
              else
                trs = td.get_treasure(player)
              end
            else
              trs = td.get_treasure(player)
            end

            get_treasures(trs[0], trs[2], trs[1])
            get_quest_treasure_event(*trs) unless trs[0] == TG_OWN_CARD
          end
        end
      end
    end

    # その場所は終点かい？
    def check_end_position?(inv, land_no)
      # クエストインベントリが存在するか？
      unless inv && inv.avatar_id == id
        ret = ERROR_QUEST_INV_IS_NONE
        return ret
      end
      # 終点ポジションに含まれるか調べる
      if inv.quest.get_end_position_set.index(land_no)
        ret = 0
      else
        ret = 1
      end
      ret
    end

    def clear_quest_deck(deck_index)
      # バインダーではなく、きちんとデッキは存在するか
      if deck_index
        unless deck_index != 0 && chara_card_decks[deck_index]
          ret = ERROR_NOT_EXIST_DECK
          return ret
        end
        # デッキはクエスト中か
        unless chara_card_decks[deck_index].status == CDS_QUEST
          ret = ERROR_DECK_IS_ALREADY_QUESTED
          return ret
        end
        chara_card_decks[deck_index].status = CDS_NONE
        chara_card_decks[deck_index].save_changes
      end
    end

    # クエストクリアする
    def quest_all_clear(inv, deck_index, no, win = false, r = RESULT_PO_DELETE)
      # ダメージを０に戻す
      set_damage_set(inv, [0, 0, 0])
      # デッキをクリアにする
      clear_quest_deck(deck_index)
      # クエストのインベント1リを削除する
      quest_delete(inv, win)
      # クリスマスイベント 2011/12/14～28期間限定
      set_quest_point(Unlight::QuestClearLog.create_log(id, inv.id, no, r, server_type, floor_count)) # By_K2
      # 初心者レコード
      if ROOKIE_QUEST_01[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(ROOKIE_QUEST_01[1])
      end
      # イベントレコード
      if EVENT_QUEST_01[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_01[1])
      end
      if EVENT_QUEST_02[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_02[1])
      end
      if EVENT_QUEST_03[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_03[1])
      end
      if EVENT_QUEST_04[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_04[1])
      end
      if EVENT_QUEST_05[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_05[1])
      end
      if EVENT_QUEST_06[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_06[1])
      end
      if EVENT_QUEST_07[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_07[1])
      end
      if EVENT_QUEST_08[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_08[1])
      end
      if EVENT_QUEST_09[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_09[1])
      end
      if EVENT_QUEST_10[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_10[1])
      end
      if EVENT_QUEST_11[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_11[1])
      end
      if EVENT_QUEST_12[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_12[1])
      end
      if EVENT_QUEST_13[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_13[1])
      end
      if EVENT_QUEST_14[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_14[1])
      end
      if EVENT_QUEST_15[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_15[1])
      end
      if EVENT_QUEST_16[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_16[1])
      end
      if EVENT_QUEST_17[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_17[1])
      end
      if EVENT_QUEST_18[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_18[1])
      end
      if EVENT_QUEST_19[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_19[1])
      end
      if EVENT_QUEST_20[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_20[1])
      end
      if EVENT_QUEST_21[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_21[1])
      end
      if EVENT_QUEST_22[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_22[1])
      end
      if EVENT_QUEST_23[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_23[1])
      end
      if EVENT_QUEST_24[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_24[1])
      end
      if EVENT_QUEST_25[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_25[1])
      end
      if EVENT_QUEST_26[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_26[1])
      end
      if EVENT_QUEST_27[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_27[1])
      end
      if EVENT_QUEST_28[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_28[1])
      end
      if EVENT_QUEST_29[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_29[1])
      end
      if EVENT_QUEST_30[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_30[1])
      end
      if EVENT_QUEST_31[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_31[1])
      end
      if EVENT_QUEST_32[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_32[1])
      end
      if EVENT_QUEST_33[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_33[1])
      end
      if EVENT_QUEST_34[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_34[1])
      end
      if EVENT_QUEST_35[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_QUEST_35[1])
      end

      # 炎の聖女レコード
      if GODDESS_OF_FIRE_QUEST_01[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(GODDESS_OF_FIRE_QUEST_01[1])
      end
      if GODDESS_OF_FIRE_QUEST_02[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(GODDESS_OF_FIRE_QUEST_02[1])
      end
      if GODDESS_OF_FIRE_QUEST_03[0].include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(GODDESS_OF_FIRE_QUEST_03[1])
      end

      if (20_568..20_618).cover?(inv.quest_id) && r == RESULT_WIN
        achievement_check([348, 349, 350, 351, 352, 353])
      elsif (20_619..20_643).cover?(inv.quest_id) && r == RESULT_WIN
        3.times { achievement_check([348, 349, 350, 351, 352, 353]) }
      elsif (10_001..10_288).cover?(inv.quest_id) && r == RESULT_WIN
        5.times { achievement_check([348, 349, 350, 351, 352, 353]) } # 10回回すとサーバが一時停止するので、もしもう一度やるときは改善が必要
      end

      # 201408イベント
      if TOTAL_EVENT_RANKING_TYPE_ACHIEVEMENT && r == RESULT_WIN && EVENT_1408_QUEST_IDS.key?(inv.quest_id)
        add_point = EVENT_1408_QUEST_IDS[inv.quest_id]
        chara_ids = chara_card_decks[deck_index].cards.map(&:charactor_id)
        chara_ids.each do |chara_id|
          if EVENT_1408_ADD_POINT_CHARA_IDS.index(chara_id)
            add_point *= EVENT_1408_POINT_COEFFICIENT
            break
          end
        end
        # ポイント加算レコード更新
        achievement_check([TOTAL_EVENT_RANKING_ACHIEVEMENT_ID], nil, add_point)
      end

      # 人気投票ポイント加算レコード
      if EVENT_CHARA_VOTE_QUEST_IDS.include?(inv.quest_id) && r == RESULT_WIN
        achievement_check(EVENT_CHARA_VOTE_RECORD_IDS, nil, chara_card_decks[deck_index].current_chara_cost)
      end
    end

    # 途中で抜けた場合、冒険途中のクエストは消されて、デッキのステータスはすべて未クエストになる(再ログイン時に行う)
    def quest_all_out
      avatar_quest_inventories.each do |a|
        if a.status == QS_INPROGRESS || a.status == QS_SOLVED || a.status == QS_FAILED
          a.clear_all(false)
          @event.quest_deleted_event(a.id) if @event
          avatar_quest_inventories.delete(a)
          Unlight::QuestClearLog.create_log(id, a.id, nil, RESULT_PO_DELETE, server_type, floor_count) # By_K2
        end
      end
      chara_card_decks.each do |c|
        if c.status == CDS_QUEST
          c.status = CDS_NONE
          c.save_changes
        end
      end
    end

    # 現在進行しているクエストのHPを全回復させる
    def quest_chara_all_heal
      ret = -1
      # ダメージを０に戻す
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_INPROGRESS
          set_damage_set(aqi, [0, 0, 0])
          ret = 0
        end
      end
      ret
    end

    # 現在進行しているクエストのHPを回復させる
    def quest_chara_heal(v)
      # ダメージをv回復させるに戻す
      ret = -1
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_INPROGRESS
          aqi.damage_heal([v, v, v])
          ret = 0
          @event.quest_deck_state_update_event(aqi.deck_index, aqi.status, aqi.hp0, aqi.hp1, aqi.hp2) if @event
        end
      end
      ret
    end

    # APMAX数を増やす
    def inc_ap_max(i)
      # nikの時デフォルト値を入れる
      self.energy_max = 5 unless energy_max
      self.energy_max = energy_max + i
      @event.update_energy_max_event if @event
      save_changes
      0
    end

    # フレンドMAX数を増やす
    def inc_friend_max(i)
      # nikの時デフォルト値を入れる
      self.friend_max = 10 unless friend_max
      self.friend_max = friend_max + i
      @event.update_friend_max_event if @event
      save_changes
      0
    end

    # パーツMAX数を増やす
    def inc_part_max(i)
      # nikの時デフォルト値を入れる
      self.part_inventory_max = Unlight::AP_INV_MAX unless part_inventory_max
      self.part_inventory_max = part_inventory_max + i
      @event.update_part_max_event if @event
      save_changes
      0
    end

    # 勝敗をリセット
    def reset_result
      self.win = 0
      self.lose = 0
      self.draw = 0
      @event.update_result_event if @event
      save_changes
      0
    end

    # BPをリセット
    def reset_bp
      self.point = DEFAULT_RATING_POINT
      Unlight::TotalDuelRanking.update_ranking(id, name, self.point, server_type)
      @event.update_result_event if @event
      save_changes
      0
    end

    # By_K2
    def get_bp
      self.point
    end

    # クエスト進行度を増やす
    def inc_quest_clear_num(i, save = true)
      self.quest_clear_num = quest_clear_num + i
      @event.quest_clear_num_update_event(quest_clear_num) if @event
      save_changes if save
      0
    end

    # クエストマップ進行度を増やす
    def inc_quest_map_clear_num(i)
      ret = -1
      map_id = quest_flag + i
      if quest_flag < map_id
        self.quest_flag = map_id
        self.quest_clear_num = 0
        if @event
          @event.quest_clear_num_update_event(quest_clear_num)
          @event.quest_flag_update_event(quest_flag)
        end
        ret = 0
      end
      save_changes
      ret
    end

    # イベントクエストマップ進行度を増やす
    def inc_event_quest_map_clear_num(i)
      ret = -1
      eqf_inv = get_event_quest_flag_inventory
      if eqf_inv
        map_id = eqf_inv.quest_flag + i
        if eqf_inv.quest_flag < map_id
          quest_map_clear(map_id)
          ret = 0
        end
      end
      ret
    end

    # クエスト進行中か？
    def quest_inprogress?
      ret = false
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_INPROGRESS
          ret = true
          break
        end
      end
      ret
    end

    # クエスト進行中か？
    def quest_dameged?
      ret = false
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_INPROGRESS
          ret = aqi.damaged?
          break
        end
      end
      ret
    end

    # クエストスタート地点から進行してるか？
    def quest_progress_and_start?
      ret = false
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_INPROGRESS && aqi.progress != 0
          ret = true
          break
        end
      end
      ret
    end

    # クエストの進行度が最大か？
    def quest_flag_capaciry?(map_id = 0)
      cap = QUEST_CAP
      if map_id < QUEST_TUTORIAL_MAP_START
        cap = QUEST_CAP
      elsif map_id < QUEST_EVENT_MAP_START
        cap = TUTORIAL_QUEST_CAP
      elsif map_id < QUEST_CHARA_VOTE_MAP_START
        cap = EVENT_QUEST_CAP
      else
        cap = CHARA_VOTE_QUEST_CAP
      end
      get_quest_flag(map_id) <= cap
    end

    # クエストの進行度が最大か？
    def quest_clear_capaciry?(quest_map_id = 0)
      flag = 0
      clear_num = 0
      if quest_map_id < QUEST_TUTORIAL_MAP_START
        flag = quest_flag
        clear_num = quest_clear_num
      elsif quest_map_id < QUEST_EVENT_MAP_START
        eqf_inv = get_event_quest_flag_inventory(QUEST_TUTORIAL_ID)
        if eqf_inv
          flag = eqf_inv.quest_flag
          clear_num = eqf_inv.quest_clear_num
        else
          return false
        end
      elsif quest_map_id < QUEST_CHARA_VOTE_MAP_START
        eqf_inv = get_event_quest_flag_inventory
        if eqf_inv
          flag = eqf_inv.quest_flag
          clear_num = eqf_inv.quest_clear_num
        else
          return false
        end
      else
        eqf_inv = get_event_quest_flag_inventory(QUEST_CHARA_VOTE_ID)
        if eqf_inv
          flag = eqf_inv.quest_flag
          clear_num = eqf_inv.quest_clear_num
        else
          return false
        end
      end
      if QuestMap[flag + 1] && QuestMap[flag + 1].get_clear_capacity(clear_num)
        true
      else
        false
      end
    end

    # インベントリがMAXではないか？
    def quest_inventory_capacity?
      refresh
      quest_inventory_max <= quests_num
    end

    # クエストリスタート
    def quest_restart
      ret = -1
      avatar_quest_inventories.each do |aqi|
        if aqi.status == QS_INPROGRESS
          ret = 0
          aqi.restart_quest
          # ダメージを０に戻す
          set_damage_set(aqi, [0, 0, 0])
          @event.quest_progress_update_event(aqi.id, aqi.progress) if @event
          # スタート地点にもどす
          @event.quest_state_update_event(aqi.id, aqi.status, aqi.quest_id) if @event
        end
      end
      ret
    end

    def update_quest_clear_num(i, map_id = 0)
      if map_id < QUEST_TUTORIAL_MAP_START
        self.quest_clear_num = quest_clear_num + i
        @event.quest_clear_num_update_event(quest_clear_num) if @event
      elsif map_id < QUEST_EVENT_MAP_START
        eqf_inv = get_event_quest_flag_inventory(QUEST_TUTORIAL_ID)
        if eqf_inv
          eqf_inv.inc_quest_clear_num(i)
          @event.event_quest_clear_num_update_event(QUEST_TYPE_TUTORIAL, eqf_inv.quest_clear_num) if @event
        end
      elsif map_id < QUEST_CHARA_VOTE_MAP_START
        eqf_inv = get_event_quest_flag_inventory
        if eqf_inv
          eqf_inv.inc_quest_clear_num(i)
          @event.event_quest_clear_num_update_event(QUEST_TYPE_EVENT, eqf_inv.quest_clear_num) if @event
        end
      else
        eqf_inv = get_event_quest_flag_inventory(QUEST_CHARA_VOTE_ID)
        if eqf_inv
          eqf_inv.inc_quest_clear_num(i)
          @event.event_quest_clear_num_update_event(QUEST_TYPE_CHARA_VOTE, eqf_inv.quest_clear_num) if @event
        end
      end
    end

    # クエストマップを攻略済みにする
    # クエスト進行度を更新する
    def quest_map_clear(map_id)
      if map_id < QUEST_TUTORIAL_MAP_START
        self.quest_flag = map_id
        self.quest_clear_num = 0
        if @event
          @event.quest_clear_num_update_event(quest_clear_num)
          @event.quest_flag_update_event(quest_flag)
        end
      elsif map_id < QUEST_EVENT_MAP_START
        eqf_inv = get_event_quest_flag_inventory(QUEST_TUTORIAL_ID)
        if eqf_inv
          eqf_inv.quest_map_clear(map_id)
          if @event
            @event.event_quest_clear_num_update_event(QUEST_TYPE_TUTORIAL, eqf_inv.quest_clear_num)
            @event.event_quest_flag_update_event(QUEST_TYPE_TUTORIAL, eqf_inv.quest_flag)
          end
        end
      elsif map_id < QUEST_CHARA_VOTE_MAP_START
        eqf_inv = get_event_quest_flag_inventory
        if eqf_inv
          eqf_inv.quest_map_clear(map_id)
          if @event
            @event.event_quest_clear_num_update_event(QUEST_TYPE_EVENT, eqf_inv.quest_clear_num)
            @event.event_quest_flag_update_event(QUEST_TYPE_EVENT, eqf_inv.quest_flag)
          end
        end
      else
        eqf_inv = get_event_quest_flag_inventory(QUEST_CHARA_VOTE_ID)
        if eqf_inv
          eqf_inv.quest_map_clear(map_id)
          if @event
            @event.event_quest_clear_num_update_event(QUEST_TYPE_CHARA_VOTE, eqf_inv.quest_clear_num)
            @event.event_quest_flag_update_event(QUEST_TYPE_CHARA_VOTE, eqf_inv.quest_flag)
          end
        end
      end
    end

    # デュエルの無料回数をリセットする
    def reset_free_duel_count
      self.free_duel_count = Unlight::FREE_DUEL_COUNT
      save_changes
      @event.use_free_duel_count_event if @event
    end

    # デュエルでAP消費
    def duel_energy_use(use_ap)
      is_free_count = false
      refresh
      if free_duel_count.positive?
        self.free_duel_count -= 1
        save_changes
        @event.use_free_duel_count_event(false) if @event
        is_free_count = true
      else
        energy_use(use_ap)
      end
      is_free_count
    end

    # デュエルでAPチェック
    def duel_check_energy(ap)
      if ap.nil?
        false
      else
        refresh
        self.free_duel_count.positive? || self.energy >= ap
      end
    end

    # ゲーム後使用武器のなかで合成武器のパッシブがあれば回数消費
    def combine_weapon_passive_cnt_update
      check_list = duel_deck.check_use_combine_passive
      check_list.each do |data|
        inv = data[:inv]
        # 更新内容をクライアントに通知
        if @event
          @event.update_combine_weapon_data_event(
            inv.id, # inv_id
            inv.card_id, # card_id
            inv.combine_base_sap, # base_sap
            inv.combine_base_sdp, # base_sdp
            inv.combine_base_aap, # base_aap
            inv.combine_base_adp, # base_adp
            inv.combine_base_max, # base_max
            inv.combine_add_sap, # add_sap
            inv.combine_add_sdp, # add_sdp
            inv.combine_add_aap, # add_aap
            inv.combine_add_adp, # add_adp
            inv.combine_add_max, # add_max
            inv.get_all_passive_id.join('|'), # passive_id
            inv.card.restriction, # restriction
            inv.combine_cnt_str, # cnt
            inv.combine_cnt_max_str, # cnt_max
            inv.level, # level
            inv.exp, # exp
            inv.combine_passive_num_max, # passive_num_max
            inv.combine_passive_pass_set.join('|'), # passive_pass_set
            data[:vani_psv_ids].join('|') # vanish_passive_ids
          )
        end
      end
    end

    def get_other_avatar_info_set
      [
        id,
        name,
        self.level,
        setted_parts_list_str,
        self.point
      ]
    end

    def get_avatar_info_set
      check_time_over_part(false)
      # すべてのパーツの更新値をチェックして導入
      all_equiped_parts_check
      save_changes

      SERVER_LOG.info("<UID:#{player_id}>DataServer: [#{__method__}] #{part_inventory_max} #{Unlight::AP_INV_MAX}")

      # 再利用する為、ここで取得
      cards_arr = cards_list(false)
      ret = [
        id || 0,
        name || '',
        self.gems || 0,
        self.exp || 0,
        self.level || 0,
        self.energy || 0,
        energy_max || 0,
        recovery_interval || 0,
        get_next_recovery_time(false) || 0,
        self.point || 0,
        self.win || 0,
        self.lose || 0,
        self.draw || 0,
        parts_num || 0,
        part_inventories_list_str(false) || '',
        part_list_str(false) || '',
        part_used_list_str(false) || '',
        parts_end_at_list_str(false) || '',
        items_num || 0,
        item_inventories_list_str(false) || '',
        item_list_str(false) || '',
        item_state_list_str(false) || '',
        decks_num || 0,
        deck_name_list_str(false) || '',
        deck_kind_list_str(false) || '',

        deck_level_list_str(false) || '',
        deck_exp_list_str(false) || '',

        deck_status_list_str(false) || '',
        deck_cost_list_str(false) || '',
        deck_max_cost_list_str(false) || '',

        cards_num || 0,
        inventories_list_str(false) || '',
        cards_list_str(false, cards_arr) || '',
        deck_index_list_str(false) || '',
        deck_position_list_str(false) || '',
        slots_num || 0,
        slot_inventories_list_str(false) || '',
        slots_list_str(false) || '',
        slot_type_list_str(false) || '',
        slot_combined_list_str(false) || '',
        slot_combine_data_list_str(false) || '',
        slot_deck_index_list_str(false) || '',
        slot_deck_position_list_str(false) || '',
        slot_card_position_list_str(false) || '',

        quest_inventory_max || 0,
        quests_num || 0,
        quest_inventories_list_str(false) || '',
        quest_id_list_str(false) || '',
        quest_status_list_str(false) || '',
        quest_find_time_list_str(false) || '',
        quest_ba_name_list_str(false) || '',

        quest_flag,
        quest_clear_num,

        friend_max || 10,
        part_inventory_max || 30,
        self.free_duel_count || 0,

        exp_pow || 0,
        gem_pow || 0,
        quest_find_pow || 0,

        current_deck || 0,

        sale_type || 0,
        get_sale_limit_rest_time(false) || 0,

        favorite_chara_id || 0,

        floor_count || 0, # By_K2

        get_event_quest_flag || 0,
        get_event_quest_clear_num || 0,

        get_event_quest_flag(QUEST_TUTORIAL_ID) || 0,
        get_event_quest_clear_num(QUEST_TUTORIAL_ID) || 0,

        get_event_quest_flag(QUEST_CHARA_VOTE_ID) || 0,
        get_event_quest_clear_num(QUEST_CHARA_VOTE_ID) || 0
      ]

      # キャラカードに関するアチーブメントのチェックをしてしまう
      achievement_check(Achievement.get_card_check_achievement_ids, { is_update: false, list: cards_arr })

      ret
    end

    # アチーブメント情報を文字列で返す
    def get_achievement_info_set(r = true)
      refresh if r
      id_list = []
      state_list = []
      progress_list = []
      end_at_list = []
      code_list = []
      achievement_inventories.each do |p|
        id_list << p.achievement_id
        state_list << p.state
        ach = p.achievement
        set_val = ach.get_progress(self, p)
        set_val ||= p.progress
        progress_list << set_val
        end_at_str = p && !p.end_at.nil? ? p.end_at.strftime('%a %b %d %H:%M:%S %Z %Y') : ''
        end_at_list << end_at_str
        code_list << p.code
      end
      id_list_str = id_list.join(',')
      state_list = state_list.join(',')
      progress_list = progress_list.join('_')
      end_at_list = end_at_list.join(',')
      code_list = code_list.join(',')
      [id_list_str, state_list, progress_list, end_at_list, code_list]
    end

    # アチーブメントインベントリのIDのリストを文字列で返す
    def achievement_inventories_list_str(r = true)
      refresh if r
      ret = achievement_inventories.map(&:achievement_id)
      ret.join(',')
    end

    # アチーブメントインベントリのstateのリストを文字列返す
    def achievement_inventories_state_list_str(r = true)
      refresh if r
      ret = achievement_inventories.map(&:state)
      ret.join(',')
    end

    # アチーブメントインベントリのprogressのリストを文字列返す
    def achievement_inventories_progress_list_str(r = true)
      ret = []
      refresh if r
      achievement_inventories.each do |p|
        ach = p.achievement
        set_val = ach.get_progress(self, p)
        set_val ||= p.progress
        ret << set_val
      end
      ret.join('_')
    end

    # アチーブメントインベントリのend_atのリストを文字列返す
    def achievement_inventories_end_at_list_str(r = true)
      ret = []
      refresh if r
      achievement_inventories.each do |p|
        ret << (p.end_at) ? p.end_at.strftime('%a %b %d %H:%M:%S %Z %Y') : ''
      end
      ret.join(',')
    end

    # アチーブメントのProgress更新(すでにクリア済みのもの)
    def cleared_achievement_progress_update
      achievement_inventories.each do |ai|
        # 条件は成功済みか？
        ai.refresh
        if ai.state != ACHIEVEMENT_STATE_START
          # タイムオーバーしているか？
          unless ai.check_time_over?
            ach = Achievement[ai.achievement_id]
            ach.progress_update(self, false, ai) if ach
          end
        end
      end
    end

    # カード取得チェックアチーブメント
    def get_card_level_record_check(card_ids)
      new_cards = card_ids.map do |c_id|
        CharaCard[c_id]
      end
      check_ids = Achievement.get_card_level_record(new_cards) if new_cards && new_cards.size
      # SERVER_LOG.info("<UID:#{self.player_id}>Avatar: [#{__method__}] card_ids:#{card_ids} record_ids:#{check_ids}")
      achievement_check(check_ids) if check_ids && !check_ids.empty?
    end

    # すべての週間レコードチェック
    def all_week_record_check
      week_record_check(WEEK_DUEL_ACHIEVEMENT_CHECK_IDS, WEEK_DUEL_ACHIEVEMENT_IDS)   # 週間Duel
      week_record_check(WEEK_QUEST_ACHIEVEMENT_CHECK_IDS, WEEK_QUEST_ACHIEVEMENT_IDS) # 週間Quest
      week_record_check(DAILY_ACHIEVEMENT_CHECK_IDS, DAILY_ACHIEVEMENT_CLEAR_IDS) # 週間Quest
      # 条件つきデイリーレコード
      if CONDITIONS_DAILY_ACHIEVEMENT_FLAG
        achievement_check # まずレコードチェックで条件レコードのクリア判定を済ます
        conditions_clear_record_ids = []
        achievement_inventories.each do |ai|
          # 条件レコードのインベントリのみ判定
          if CONDITIONS_DAILY_ACHIEVEMENT_IDS.key?(ai.achievement_id)
            # 条件レコードをクリアしているなら
            if ai.state == ACHIEVEMENT_STATE_FINISH
              conditions_clear_record_ids << ai.achievement_id
            end
          end
        end
        # 条件クリアしているレコードのデイリーレコードを判定
        conditions_clear_record_ids.each do |aid|
          check_ids = CONDITIONS_DAILY_ACHIEVEMENT_IDS[aid]
          if check_ids && !check_ids.empty?
            week_record_check(check_ids, check_ids)
          end
        end
      end
    end

    # end_at指定のあるレコードチェック
    def check_set_end_at_records
      drop_invs = []
      reset_flag = false
      achievement_inventories.sort_by(&:achievement_id).each do |ai|
        if DAILY_ACHIEVEMENT_IDS.include?(ai.achievement_id)
          drop_invs << ai
          if ai.is_end
            reset_flag = true
          end
        end
      end
      if reset_flag
        drop_invs.each do |ai|
          ai.finish_delete
          @event.drop_achievement_event(ai.achievement_id) if @event
        end
      end
    end

    # 週間レコードチェック
    def week_record_check(check_list, all_list)
      if check_list && !check_list.empty?
        new_ai = nil
        records = []
        # 翌日の日付を終了時間にする
        t = Time.now.utc
        d_time = DateTime.new(t.year, t.month, t.day) + 1
        next_end_at = Time.gm(d_time.year, d_time.month, d_time.day) + LOGIN_BONUS_OFFSET_TIME
        achievement_inventories.sort_by(&:achievement_id).each do |ai|
          records.push(ai) if all_list.include?(ai.achievement_id)
        end
        # SERVER_LOG.info("<UID:#{self.player_id}>LobbyServer: [#{__method__}] records:#{records}")
        if records.nil? || records.size <= 0
          # 追加されていないので、新しく追加
          new_ai = AchievementInventory.new do |b|
            b.avatar_id = id
            b.achievement_id = check_list.first
            b.end_at = next_end_at
            b.save_changes
          end
        else
          if records[-1].is_end
            delete_ids = []    # 削除するアチーブメントのID
            reset_flag = false # リセットして初期から再始動するフラグ
            if records[-1].state == ACHIEVEMENT_STATE_FINISH
              last_end_at = records[-1].end_at
              check_d_time = DateTime.new(last_end_at.year, last_end_at.month, last_end_at.day) + 1
              check_end_at = Time.gm(check_d_time.year, check_d_time.month, check_d_time.day) + LOGIN_BONUS_OFFSET_TIME + 1
              if check_end_at > next_end_at
                next_idx = 0
                check_list.each_with_index { |id, i| next_idx = i + 1 if records[-1].achievement_id == id }
                next_a_id = nil
                next_a_id = check_list[next_idx] if next_idx != 0 && next_idx < check_list.size
                if !next_a_id.nil? && next_a_id <= check_list.last
                  new_ai = AchievementInventory.new do |b|
                    b.avatar_id = self.id
                    b.achievement_id = next_a_id
                    b.end_at = next_end_at
                    b.save_changes
                  end
                else
                  reset_flag = true
                end
              else
                reset_flag = true
              end
            else
              reset_flag = true
            end
            if reset_flag
              # 一度すべてを削除する
              records.each { |row| delete_ids.push(row.achievement_id) }
              delete_ids.each do |id|
                records.each_with_index do |_row, i|
                  if id == records[i].achievement_id
                    records[i].finish_delete
                    records.delete_at(i)
                    break
                  end
                end
              end
              # アチーブメント削除イベントを送る
              delete_ids.each { |id| @event.drop_achievement_event(id) } if @event
              # 最初のを再度追加しなおす
              new_ai = AchievementInventory.new do |b|
                b.avatar_id = self.id
                b.achievement_id = check_list.first
                b.end_at = next_end_at
                b.save_changes
              end
            end
          end
        end
        if new_ai
          # アチーブメント追加イベントを送る
          @event.add_new_achievement_event(new_ai.achievement_id) if @event
          records.push(new_ai)
        end
        if records
          id_list = []
          state_list = []
          progress_list = []
          end_at_list = []
          code_list = []
          records.each do |r|
            id_list << r.achievement_id
            state_list << r.state
            set_prog = r.achievement.get_progress(self, r)
            set_prog ||= r.progress.to_s
            progress_list << set_prog
            end_at_str = r && !r.end_at.nil? ? r.end_at.strftime('%a %b %d %H:%M:%S %Z %Y') : ''
            end_at_list << end_at_str
            code_list << r.code
          end
          # アチーブメントの情報を送る
          @event.update_achievement_info_event(id_list.join(','), state_list.join(','), progress_list.join('_'), end_at_list.join(','), code_list.join(',')) if @event
        end
      end
    end

    # 週間レコードのクリアチェック
    def week_record_clear_check(check_list)
      if check_list && !check_list.empty?
        achievement_check(check_list)
        if is_daily_record_clear
          achievement_check(DAILY_ACHIEVEMENT_CLEAR_IDS)
        end
      end
    end

    # 週間レコードデイリークリアチェック
    def is_daily_record_clear
      check_list = WEEK_DUEL_ACHIEVEMENT_CHECK_IDS.concat(WEEK_QUEST_ACHIEVEMENT_CHECK_IDS)
      ret = true
      achievement_inventories.each do |ai|
        # 一つでも終了していないのがあれば、未クリア判定
        if check_list.include?(ai.achievement_id) && ai.state != ACHIEVEMENT_STATE_FINISH
          ret = false
          break
        end
      end
      ret
    end

    # アチーブメントチェック（noがある場合はそのナンバーだけをチェック）
    def achievement_check(no = false, card_list = nil, point = 0, zero_check = true, loop_stop = false) # rubocop:disable Metrics/ParameterLists
      # 更新情報送信の為、ID、State、Progressを保持
      id_list = []
      state_list = []
      progress_list = []
      end_at_list = []
      code_list = []

      # 現行で削除されたレコードIDを保持
      now_exclusion_list = []

      # 0のイベントが生じているかチェック
      check_new_achievement if zero_check
      achievement_inventories.each do |ai|
        # 削除処理を行ったレコードか判定
        next if !now_exclusion_list.empty? && (now_exclusion_list.include?(ai.achievement.id.to_s) || now_exclusion_list.include?(ai.achievement.id))
        next unless ai.state == ACHIEVEMENT_STATE_START && (no == false || (no && ai.achievement && no.include?(ai.achievement.id)))
        next if ai.check_time_over?

        # 条件は成功しているか？
        ai.refresh
        # SERVER_LOG.info("<UID:#{self.player_id}>Avatar: [#{__method__}] ai.achievement.id:#{ai.achievement.id} ai.state:#{ai.state}")
        if ai.state == ACHIEVEMENT_STATE_START && ai.achievement.cond_check(self, no, ai, card_list, point)
          achievement_notice_items(ai)
          achievement_notice_selectable_items(ai)
          achievement_notice_rookie_sale(ai)

          # アチーブメントの状態をクリアにする
          ai.finish
          # 削除するアチーブメントがあるかチェック
          check_exclusion_achievement(ai.achievement.get_exclusion_list, card_list)
          now_exclusion_list.concat(ai.achievement.get_exclusion_list)
          now_exclusion_list.uniq!
          # 新たにアチーブメントが増えるかチェックする
          check_new_achievement(ai.achievement.id, card_list)

          increment_achievement_loop(ai, loop_stop)
          check_set_loop_achievement(ai.achievement.get_set_loop_list, card_list)

          # Achievemnt報酬で武器カード取得した場合、レコードクリア処置後にレコードチェックを行う（二重クリア防止）
          if @get_weapon_record_check
            achievement_check(GET_WEAPON_ACHIEVEMENT_IDS) if GET_WEAPON_ACHIEVEMENT_IDS
            @get_weapon_record_check = false
          end
          # check判定をしたアチーブメントは更新の為、情報を保持
        end
        id_list.push(ai.achievement_id)
        state_list.push(ai.state)
        set_prog = ai.achievement.get_progress(self, ai)
        set_prog ||= ai.progress
        progress_list.push(set_prog)
        end_at_str = ai && !ai.end_at.nil? ? ai.end_at.strftime('%a %b %d %H:%M:%S %Z %Y') : ''
        end_at_list << end_at_str
        code_list << ai.code
      end

      # アチーブメントの情報を送る
      @event.update_achievement_info_event(id_list.join(','), state_list.join(','), progress_list.join('_'), end_at_list.join(','), code_list.join(',')) if @event
    end

    # クリアしたアチーブメントによって新しいアチーブメント追加されるかチェック
    def check_new_achievement(a_id = 0, card_list = nil)
      # 更新情報送信の為
      id_list = []
      state_list = []
      progress_list = []
      end_at_list = []
      code_list = []

      # 追加されるであろうアチーブメント列挙
      Achievement.get_new_list(a_id).each do |a|
        r = true
        achievement_inventories.each do |ai|
          # すでにクリア|実行中かをチェック
          if ai.achievement_id == a.id
            r = false
            break
          end
          # 新しくつくる
        end
        if r
          set_state = ACHIEVEMENT_STATE_START
          set_state = ACHIEVEMENT_STATE_FAILED if EVENT_DUEL_05.include?(a.id) && self.level > LOW_AVATAR_DUEL_RECORD_LV

          new_ai = AchievementInventory.new do |b|
            b.avatar_id = id
            b.achievement_id = a.id
            b.state = set_state
            end_at = a.get_end_at
            b.end_at = end_at if end_at
            b.save_changes
          end
          # 必要ならprogressの引継ぎ
          new_ai.progress_inheriting
          # アチーブメント追加イベントを送る
          @event.add_new_achievement_event(a.id) if @event && set_state == ACHIEVEMENT_STATE_START
          refresh
          if a.is_any_time_check
            if Achievement.is_chara_card_check(a.id)
              achievement_check([a.id], card_list)
            else
              achievement_check([a.id], nil, 0, false)
            end
          end

          id_list.push(new_ai.achievement_id)
          state_list.push(new_ai.state)
          set_prog = new_ai.achievement.get_progress(self, new_ai)
          set_prog ||= new_ai.progress
          progress_list.push(set_prog)
          end_at_str = new_ai && !new_ai.end_at.nil? ? new_ai.end_at.strftime('%a %b %d %H:%M:%S %Z %Y') : ''
          end_at_list << end_at_str
          code_list << new_ai.code
        end
      end

      # アチーブメントの情報を送る
      @event.update_achievement_info_event(id_list.join(','), state_list.join(','), progress_list.join('_'), end_at_list.join(','), code_list.join(',')) if @event
    end

    # クリアしたアチーブメントによってアチーブメントが消されるかチェック
    def check_exclusion_achievement(a_set, card_list = nil)
      # SERVER_LOG.info("<UID:#{self.player_id}>Avatar: [check_exclu_adhi]")
      unless a_set.empty?
        # 消されるであろうアチーブメント列挙
        achievement_inventories.each do |a|
          if a_set.include?(a.achievement_id.to_s)
            a.failed
            @event.delete_achievement_event(a.achievement_id) if @event
            refresh
            if Achievement.is_chara_card_check(a.achievement_id)
              achievement_check([a.achievement_id], card_list)
            else
              achievement_check
            end
          end
        end
      end
    end

    # 繰り返し可能なアチーブメントを追加する
    def add_loop_achievement(ai = 0)
      if ai != 0
        # 初期値に戻す
        ai.restart
        # アチーブメント追加イベントを送る
        @event.add_new_achievement_event(ai.achievement.id) if @event
        # refresh
        # achievement_check ループレコードが発生するで新しいレコードが毎回べつに発生するのはありえるのか？
      end
    end

    # 繰り返し可能なアチーブメントを終了させる
    def stop_loop_achievement(ai = 0)
      if ai != 0
        # 失敗に変更する
        ai.failed
        # アチーブメント削除イベントを送る
        @event.delete_achievement_event(ai.achievement.id) if @event
      end
    end

    # 複数セットのアチーブメントでループするアチーブメントかチェック
    def check_set_loop_achievement(a_set, card_list = nil)
      # SERVER_LOG.info("<UID:#{self.player_id}>Avatar: [#{__method__}]")
      unless a_set.empty?
        # 消されるであろうアチーブメント列挙
        achievement_inventories.each do |a|
          if a_set.include?(a.achievement_id.to_s)
            a.finish_delete
            @event.drop_achievement_event(a.achievement_id) if @event
          end
        end
        # ループするリストの先端のものを新規追加
        new_ac_id = a_set.min_by(&:to_i).to_i
        new_ai = AchievementInventory.new do |b|
          b.avatar_id = id
          b.achievement_id = new_ac_id
          b.save_changes
        end
        # 必要ならprogressの引継ぎ
        new_ai.progress_inheriting
        # アチーブメント追加イベントを送る
        @event.add_new_achievement_event(new_ac_id) if @event
        refresh
        if Achievement.is_chara_card_check(new_ac_id)
          achievement_check([new_ac_id], card_list)
        else
          achievement_check
        end
      end
    end

    # 特定のアチーブメントを取得
    def get_achievementB(achi_id)
      ret = nil
      achievement_inventories.each do |ai|
        if ai.achievement_id == achi_id
          ret = ai
          break
        end
      end
      ret
    end

    # 失敗状態に変更する
    def failed_achievement(a_set)
      unless a_set.empty?
        # 初期値に戻す
        achievement_inventories.each do |a|
          if a_set.include?(a.achievement_id) && a.state == ACHIEVEMENT_STATE_START
            a.failed
            @event.delete_achievement_event(a.achievement_id) if @event
          end
        end
      end
    end

    # 現在のイベントポイント
    # =====================================================
    def event_point
      ret = 0
      if TOTAL_EVENT_RANKING_TYPE_FRIEND
        ret = event_point_friend
      elsif TOTAL_EVENT_RANKING_TYPE_ACHIEVEMENT
        ret = event_point_achievement
      elsif TOTAL_EVENT_RANKING_TYPE_ITEM_NUM
        ret = event_point_item_num
      elsif TOTAL_EVENT_RANKING_TYPE_ITEM_POINT
        ret = event_point_item_point
      elsif TOTAL_EVENT_RANKING_TYPE_PRF_ALL_DMG
        ret = event_point_prf_all_dmg
      end
      ret
    end

    # アイテム個数などでポイント管理するイベント時の処理(フレンド分も換算ver)
    def event_point_friend
      # SERVER_LOG.info("<UID:#{self.player_id}>Avatar: [#{__method__}]")
      ret = 0
      item_inventories.each do |a|
        if a.avatar_item_id >= EVENT_WITH_FRIEND_ITEM_ID_START && a.avatar_item_id <= EVENT_WITH_FRIEND_ITEM_ID_END
          ret += EVENT_ITEM_POINTS[a.avatar_item_id]
        end
      end
      links = FriendLink.get_link(player_id, server_type)
      friend_item_point = 0
      links.each do |a|
        if a.friend_type == FriendLink::TYPE_FRIEND
          other_avatar = Player[a.other_id(player_id)].current_avatar if Player[a.other_id(player_id)]
          if other_avatar
            other_avatar.item_inventories.each do |i|
              if i && !i.avatar_item_id.nil?
                if i.avatar_item_id >= EVENT_WITH_FRIEND_ITEM_ID_START && i.avatar_item_id <= EVENT_WITH_FRIEND_ITEM_ID_END
                  friend_item_point += EVENT_ITEM_POINTS[i.avatar_item_id]
                end
              end
            end
          end
        end
      end
      # フレンド分は全部数え終えた後、調整してから加算
      ret += friend_item_point / FRIEND_COEFFICIENT
      ret
    end

    # アチーブメントでポイント管理する場合のイベント時の処理
    def event_point_achievement
      ret = 0
      achievement_inventories.each do |ai|
        if ai.achievement_id == TOTAL_EVENT_RANKING_ACHIEVEMENT_ID
          ret = ai.progress
          break
        end
      end
      ret
    end

    # アイテム個数を換算する場合のイベント時の処理 ！！！アバター個人の分はないので、0を返す
    def event_point_item_num
      0
    end

    # アイテムポイントを換算する場合のイベント時の処理 ！！！アバター個人の分はないので、0を返す
    def event_point_item_point
      0
    end

    # 渦の総ダメージ数を換算する場合のイベント時の処理 ！！！アバター個人の分はないので、0を返す
    def event_point_prf_all_dmg
      0
    end

    # 自分のランク情報を取得
    def get_rank(t, server_type)
      case t
      when RANK_TYPE_TD
        ret = TotalDuelRanking.get_ranking(id, server_type, self.point)
      when RANK_TYPE_TQ
        ret = TotalQuestRanking.get_ranking(id, server_type, self.quest_point)
      when RANK_TYPE_WD
        ret = WeeklyDuelRanking.get_ranking(id, server_type)
      when RANK_TYPE_WQ
        ret = WeeklyQuestRanking.get_ranking(id, server_type)
      when RANK_TYPE_TE
        ret = TotalEventRanking.get_ranking(id, server_type, event_point)
      when RANK_TYPE_TV
        # キャラ人気投票は自分(Avatar)の情報はない
        ret = { rank: 0, arrow: 0, point: 0 }
      end
      ret
    end

    # ProfoundIdからInventoryを取得
    def get_profound_inventory_from_prf_id(prf_id)
      profound_inventories.find { |v| v[:profound_id] == prf_id }
    end

    # 自分の渦戦闘のランク情報を取得
    def get_profound_rank(inv_id)
      ret = nil
      prf_id = 0
      prf_inv = profound_inventories.find { |v| v[:id] == inv_id }
      if prf_inv
        prf_inv.init_ranking
        ret = prf_inv.get_self_rank
        prf_id = prf_inv.profound_id
      end
      { prf_id:, ret: }
    end

    def get_profound_rank_from_inv(prf_inv)
      ret = nil
      if prf_inv
        prf_inv.init_ranking
        ret = prf_inv.get_self_rank
        prf_id = prf_inv.profound_id
      end
      { prf_id:, ret: }
    end

    # 渦戦闘の報酬を取得
    def get_profound_tresure(trs_list)
      ret = []
      trs_list.each do |trs|
        get_treasures(trs[:type], trs[:id], trs[:sct_type], trs[:num])
        ret << "#{trs[:type]}_#{trs[:id]}_#{trs[:num]}_#{trs[:sct_type] || 0}"
      end
      ret
    end

    # お詫びアイテムを取得
    def get_apology_items
      if avatar_apology
        apologies = avatar_apology.get_body
        add_apology = false
        apologies.each_value do |param|
          notice_set = [param[:date]]
          param[:items].each do |i|
            r = get_treasures(i[0], i[1], i[3], i[2])
            if ERROR_PARTS_DUPE != r
              notice_set.push(i.join('_'))
            end
          end
          write_notice(NOTICE_TYPE_APOLOGY, notice_set.join(','))
          add_apology = true
        end
        avatar_apology.all_clear_body if add_apology
      end
    end

    def get_notice
      ret = ''
      if avatar_notice
        ret = avatar_notice.body
      end
      ret
    end

    def clear_notice(n, _args)
      if avatar_notice
        # 渦と選択レコード関連以外を消すように調整
        noncheck_types = PRF_NOTICE_TYPES.clone.push(NOTICE_TYPE_GET_SELECTABLE_ITEM)
        avatar_notice.get_other_type_message(noncheck_types)
        cleared_notice_set = avatar_notice.clear_body(n)
        cleared_notice_set.each_with_index do |nc, _i|
          a = nc.split(':') if nc
          if a
            case a.first.to_i
            when NOTICE_TYPE_SALE_START
              # セールのスタートチェック
              p = a[-1].split(',')
              type = p.shift.to_i
              time = p.shift.to_i
              set_sale_limit(time, type)
            when NOTICE_TYPE_INVITE_SUCC
              # 招待成功時のレコード更新チェック
              # 招待処理は被招待者が行う為、レコードが更新されない場合がある
              @event.update_achievement_info_event(*get_achievement_info_set) if @event
            when NOTICE_TYPE_GET_SELECTABLE_ITEM
            end
          end
        end
      end
    end

    def get_notice_selectable_item(args)
      arg_set = Hash[*args.split(',')]
      cnt = avatar_notice.get_type_message([NOTICE_TYPE_GET_SELECTABLE_ITEM]).split('|').size
      if cnt.positive? && !arg_set.keys.empty?
        cleared_notice_set = avatar_notice.clear_body(cnt)
        cleared_notice_set.each_with_index do |nc, _i|
          a = nc.split(':') if nc
          if a
            case a.first.to_i
            when NOTICE_TYPE_GET_SELECTABLE_ITEM
              select_index = 255
              a_id = a.last.to_i
              select_index = arg_set[a.last].to_i if arg_set[a.last]
              item_set = Achievement[a_id].get_selectable_array
              if item_set.size > select_index
                item = item_set[select_index]
                get_treasures(item[0], item[1], item[3], item[2], false)
              end
            end
          end
        end
      end
    end

    def write_notice(type, body, r = true)
      refresh if r
      AvatarNotice.write_notice(avatar_notice, id, "#{type}:#{body}")
    end

    def get_profound_notice
      ret = ''
      if avatar_notice
        ret = avatar_notice.get_type_message(PRF_NOTICE_TYPES)
      end
      ret
    end

    def profound_notice_clear(n)
      if avatar_notice
        avatar_notice.get_type_message(PRF_NOTICE_TYPES)
        avatar_notice.clear_body(n)
      end
    end

    # クエストを友人に送る
    def send_quest(a_id, qi_id)
      ret = 0
      ai = AvatarQuestInventory[qi_id]
      a = Avatar[a_id]

      # 渡すクエストインベントリが存在し、自分のもので、解決していないか？
      unless ai && ai.avatar_id == id && ai.unsolved?
        ret = ERROR_SEND_QUEST_WRONG_QUEST
        return ret
      end

      ap = ai.quest.ap

      # APが足りているか？
      unless self.energy >= ai.quest.ap
        ret = ERROR_AP_LACK
        return ret
      end

      # 届け先のアバターが存在して、相手のアバタープレイヤーと自分が友達か？
      unless  a && player.friend?(a.player_id)
        ret = ERROR_SEND_QUEST
        return ret
      end

      # 届け先のアバターが持つクエストが相手のクエストインベントリーのx5倍以下
      unless  a && a.quests_num < (a.quest_inventory_max * 5)
        ret = ERROR_SEND_QUEST_MAX
        return ret
      end

      # By_K2 (무한의탑 퀘스트는 선물불가)
      if ai.quest_id >= 99_991 && ai.quest_id <= 99_996
        ret = ERROR_SEND_QUEST_EVENT_QUEST
        return ret
      end

      # 同じIPの相手にはクエスト送ることが出来ない
      if a && a.player.last_ip == player.last_ip
        if CACHE.get("quest_sent_ip_check:#{a_id}") && player.role != ROLE_ADMIN # Adminの場合OK
          ret = ERROR_SEND_QUEST_SAME_IP
          return ret
        else
          CACHE.set("quest_sent_ip_check:#{a_id}", true, Unlight::QUEST_SEND_SAME_IP_LIMIT)
        end
      end

      # 2014クリスマスイベント用チェック 送り主以外に送ることが出来ない
      if ai.quest_id >= QE_CHRISTMAS2014_START_ID && ai.quest_id <= QE_CHRISTMAS2014_END_ID
        if ai.before_avatar_id != a_id
          ret = ERROR_SEND_QUEST_NOT_SENDER
          return ret
        end
      end

      # 特別なアイテムを装備していたときに別のクエストを差し替える 2014クリスマスイベント
      if setted_parts_id_list.include?(QEV_XMAS_PART_ID) && ai.quest.rarity >= QEV_RARITY
        ai.quest_id = QuestMap[QM_EV_XMAS2014_LAND].get_quest_id
        ai.save_changes
      end

      # イベントクエストプレゼント用チェック
      if QUEST_EVENT_QUEST_LIST.index(ai.quest_id)
        ret = ERROR_SEND_QUEST_EVENT_QUEST
        return ret
      end

      # 2014深淵の書イベント用チェック
      if EVENT_QUEST_PRESENT_2014_RECORD[0].index(ai.quest_id)
        if ai.before_avatar_id.zero?
          achievement_check(EVENT_QUEST_PRESENT_2014_RECORD[1])
        end
      end

      # 201412イベント用チェック
      if EVENT_201412_RECORD_IDS[ai.quest.rarity]
        if ai.before_avatar_id.zero? || ai.before_avatar_id.nil?
          achievement_check(EVENT_201412_RECORD_IDS[ai.quest.rarity])
        end
      end

      # 201701イベント用チェック　クエストレアリティチェック
      if EVENT_201701_RECORD_IDS[ai.quest.rarity]
        if ai.before_avatar_id.zero? || ai.before_avatar_id.nil?
          achievement_check(EVENT_201701_RECORD_IDS[ai.quest.rarity])
        end
      end

      # 実際に渡す
      energy_use(ap)
      ai.send_avatar(a_id)
      avatar_quest_inventories.delete(ai)
      @event.quest_deleted_event(ai.id) if @event
      notice_a = []
      notice_a << name
      notice_a << ai.quest_id
      # お知らせにも追記
      a.write_notice(NOTICE_TYPE_QUEST_PRESENT, notice_a.join(','))
      ret
    end

    # 個人のセール終了までの残り時間を返す
    def get_sale_limit_rest_time(r = true)
      ret = 0
      refresh if r
      # nilならセールしていない
      unless sale_limit_at.nil?
        now = Time.now.utc
        # 時間を過ぎているか
        if now <= sale_limit_at
          ret = (sale_limit_at - now).to_i
        end
      end
      ret
    end

    # セール時間を設定する
    def set_sale_limit(set_time, type = SALE_TYPE_ROOKIE)
      # 現在セール中の場合上書きしない。が、初心者セールだけは上書きする（本来は大きいセールを上書きしない）
      if !is_sale_time || type == SALE_TYPE_ROOKIE
        self.sale_type = type
        self.sale_limit_at = Time.now.utc + set_time
        save_changes
        SERVER_LOG.info("<UID:#{id}> [set_sale_limit] type:#{type} limit_at:#{sale_limit_at}")
        @event.start_sale_event(type, get_sale_limit_rest_time) if @event
      end
    end

    # セール中かどうかBooleanで返す
    def is_sale_time(add_time = 0)
      ret = false
      unless sale_limit_at.nil?
        now = Time.now.utc
        check_time = sale_limit_at + add_time
        ret = (now <= check_time)
      end
      ret
    end

    # お気に入りキャラIDを設定する
    def set_favorite_chara_id(id)
      self.favorite_chara_id = id
      save_changes
      @event.change_favorite_chara_id_event(id) if @event
      @lobby_chara_script_list = nil
    end

    # リザルト画像を設定する
    def set_result_image(id, image_no)
      refresh
      item_id = AvatarItem.filter(cond: id.to_s).first.id
      ItemInventory.where(avatar_id: self.id, avatar_item_id: item_id, state: ITEM_STATE_USING).update(state: ITEM_STATE_NOT_USE)
      if image_no.positive?
        ItemInventory.where(avatar_id: self.id, avatar_item_id: item_id).update(state: ITEM_STATE_USING)
      end
    end

    # By_K2 (무한의탑 층수 체크)
    def floor_count_check
      floor_count
    end

    # By_K2 (무한의탑 층수 UP)
    def floor_count_up
      self.floor_count = floor_count + 1
      save_changes
      @event.floor_count_update_event(floor_count) if @event
    end

    # ロビー会話シナリオを取得する
    def get_lobby_chara_scenario
      ret = []
      # 特別なシナリオを持っているかチェックする
      SERVER_LOG.info("<UID:#{id}> [get_lobby_chara_scenario]fav_id:#{favorite_chara_id}")
      scenario_inventories.each do |s|
        # 今のお気に入りキャラの特別シナリオが存在する場合
        if favorite_chara_id == s.scenario.chara_id
          ret << s.scenario
        end
      end
      if ret.empty?
        # 特別なシナリオがなかったら汎用をとってくる
        ret = Scenario.get_scenarios(favorite_chara_id)
      end
      ret.sort! { |a, b| b.priority <=> a.priority }
      ret.first
    end

    def start_lobby_chara_script
      if  @lobby_chara_script_list.nil? || @lobby_chara_script_list.size == @lobby_chara_scr_i
        s = get_lobby_chara_scenario
        if s
          scr = s.get_script_set
          @lobby_chara_script_list = scr.first
          @lobby_chara_jump_list = scr.last
          @lobby_chara_scr_i = 0
        else
          return
        end
      end
      run_lobby_chara_script
    end

    def run_lobby_chara_script
      if @lobby_chara_script_list.nil?
        [:stop]
      elsif @lobby_chara_script_list[@lobby_chara_scr_i].first == :stop
        @lobby_chara_script_list[@lobby_chara_scr_i]
      else
        @lobby_chara_scr_i += 1
        SERVER_LOG.info("<UID:#{id}> [run_lobby_chara_scr]scr_list[#{@lobby_chara_scr_i - 1}]:#{@lobby_chara_script_list[@lobby_chara_scr_i - 1]}")

        @lobby_chara_script_list[@lobby_chara_scr_i - 1]
      end
    end

    def finish_lobby_chara_script
      @lobby_chara_script_list = nil
      @lobby_chara_jump_list = nil
    end

    def get_lobby_chara_scenario_flags
      if @lobby_chara_flags.nil?
        s = ScenarioFlagInventory.filter(avatar_id: id).all.first
        if s
          @lobby_chara_flags = s.get_flag
        else
          @lobby_chara_flags = {}
        end
      end
    end

    # シナリオでジャンプ処理
    def jump_lobby_chara(j)
      @lobby_chara_scr_i = @lobby_chara_jump_list[j.to_s]
    end

    # シナリオでアイテムを渡す処理
    def give_item_lobby_chara(genr, id, num = 1, sct = 0)
      get_treasures(genr, id, sct, num)
    end

    # フラグをチェックする
    def flag_check_lobby_chara_script(flags)
      f = false
      flags[0].each do |a|
        if @lobby_chara_flags || get_lobby_chara_scenario_flags
          a[1] =~ /^\s*([=!><]=)\s*(.*)/
          case Regexp.last_match(1)
          when '=='
            f = @lobby_chara_flags[a[0]] == Regexp.last_match(2)
          when '!='
            f = @lobby_chara_flags[a[0]] != Regexp.last_match(2)
          when '>='
            f = @lobby_chara_flags[a[0]].to_i >= Regexp.last_match(2).to_i
          when '<='
            f = @lobby_chara_flags[a[0]].to_i <= Regexp.last_match(2).to_i
          end

          break unless f
        end
      end
      if f
        jump_lobby_chara(flags[1])
      end
    end

    # フラグを保存する
    def flag_set_lobby_chara_script(flags)
      p flags
      if scenario_flag_inventories.first
        scenario_flag_inventories.first.set_flag(flags[0], flags[1])
      else
        ScenarioFlagInventory.new do |s|
          s.avatar_id = id
          s.set_flag(flags[0], flags[1])
          s.save_changes
        end
      end
    end

    # イベントクエストフラグインベントリを取得
    def get_event_quest_flag_inventory(event_id = QUEST_EVENT_ID)
      ret = nil
      EventQuestFlagInventory.get_avatar_event(id).each do |eqfi|
        ret = eqfi if eqfi.event_id == event_id
      end
      unless ret
        map_start = QUEST_EVENT_MAP_START
        map_start = QUEST_TUTORIAL_MAP_START if event_id == QUEST_TUTORIAL_ID
        map_start = QUEST_CHARA_VOTE_MAP_END if event_id == QUEST_CHARA_VOTE_ID
        ret = EventQuestFlagInventory.create_inv(id, event_id, map_start)
      end
      ret
    end

    # イベントフラグを取得
    def get_event_quest_flag(event_id = QUEST_EVENT_ID)
      inv = get_event_quest_flag_inventory(event_id)
      inv ? inv.quest_flag : 0
    end

    # イベント進行度を取得
    def get_event_quest_clear_num(event_id = QUEST_EVENT_ID)
      inv = get_event_quest_flag_inventory(event_id)
      inv ? inv.quest_clear_num : 0
    end

    # イベントクエストフラグを作製する
    def create_event_quest_flag
      get_event_quest_flag_inventory(QUEST_TUTORIAL_ID)
      get_event_quest_flag_inventory
      get_event_quest_flag_inventory(QUEST_CHARA_VOTE_ID)
    end

    def get_result_images; end

    # 1日セール開始判定
    def set_one_day_sale_start_check
      SERVER_LOG.info("<UID:#{player_id}>DataServer: [#{__method__}] login_at:#{player.login_at} check at:#{ONE_DAY_SALE_CHECK_AT}")
      if ONE_DAY_SALE_FLAG
        # セールタイムが設定されてないなら
        if sale_limit_at.nil? || sale_limit_at == '' || sale_limit_at < ONE_DAY_SALE_CHECK_AT
          set_sale_limit(ONE_DAY_SALE_TIME, SALE_TYPE_ROOKIE)
        end
      end
    end

    private

    def achievement_notice_rookie_sale(ai)
      return unless ai.achievement_id == ROOKIE_SALE_CHECK_ACHEVEMENT_ID
      return unless rookie_sale?

      write_notice(NOTICE_TYPE_SALE_START, [SALE_TYPE_ROOKIE, ROOKIE_SALE_TIME].join(','))
    end

    def achievement_notice_items(ai)
      notice_items = []
      ai.achievement.get_items.each do |i|
        res = get_treasures(i[0], i[1], i[3], i[2], false)
        next if ERROR_PARTS_DUPE == res

        if @event
          @event.achievement_clear_event(ai.achievement.id, i[0], i[1], i[2], i[3] || 0)
        else
          notice_items.push("#{i[0]}_#{i[1]}_#{i[2]}_#{i[3]}")
        end
      end

      return if notice_items.empty?

      notice_items.unshift(ai.achievement.id)
      write_notice(NOTICE_TYPE_ACHI_SUCC, notice_items.join(','))
    end

    def achievement_notice_selectable_items(ai)
      selectable_items = ai.achievement.get_selectable_items
      return unless selectable_items

      # TODO: Refacto to use Enumerator#select
      allowed_items = []
      selectable_array = ai.achievement.get_selectable_array
      selectable_array.each do |item|
        if item[0] == TG_AVATAR_PART
          next if parts_dupe_check(item[1])
        end

        allowed_items << item
      end
      return if allowed_items.empty?

      write_notice(NOTICE_TYPE_GET_SELECTABLE_ITEM, ai.achievement.id.to_s)
    end

    def increment_achievement_loop(ai, stop)
      return unless ai.achievement.loop.positive?
      return stop_loop_achievement(ai) if stop

      add_loop_achievement(ai)
    end
  end

  # TODO: Move to top after resolve dependency
  require 'events/avatar_event'
end

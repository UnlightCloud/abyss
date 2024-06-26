# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # 合成条件
  class CombineCase < Sequel::Model
    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods
    plugin :caching, CACHE, ignore_exceptions: true

    # requrement 記法括弧はand同じものが複数必要ならなべる必要あり
    # 元武器のIDが1と3〜9,11〜1000{:base =>[1, 3..9, 11..1000]} # 範囲型か数字を並べる
    # 追加素材武器のIDが1001〜1100{:add =[[1001..1100]]} # 範囲型か数字を並べる
    # 追加素材武器のIDが1001〜1100が二つ{:add =[[1001..1100],[1001..1100]]} # 範囲型か数字を並べる

    MOD_LIST = [
      nil,
      :add_point,                # 1 ポイントを固定値上昇(引数 type:Symbol,num:int)
      :add_point_rnd,            # 2 ポイントをランダム上昇(引数 type:Symbol,min:int,max:int)
      :shift_base_point_rnd,     # 3 特定ポイントを他の特定ポイントにランダムで移す(引数 type:Symbol,num:int)
      :shift_add_point_rnd,      # 4 特定ポイントを他の特定ポイントにランダムで移す(引数 type:Symbol,num:int)
      :shift_base_point,         # 5 特定ポイントを他のポイントに移す(引数 from_type:Symbol,to_type:Symbol,num:int)
      :shift_add_point,          # 6 特定ポイントを他のポイントに移す(引数 from_type:Symbol,to_type:Symbol,num:int)
      :set_max,                  # 7 最大合計基本ポイントを特定値にセット(引数 type:Symbol,max:int)
      :set_passive,              # 8 一時パッシブをつけるになる(引数 passive_id:int)
      :change_weapon # 9 合成武器になるようパラメータ調整(引数 type:Symbol,num:int)
    ]
    MOD_POINT_BASE_LIST = %i[base_sap base_sdp base_aap base_adp]
    MOD_POINT_ADD_LIST = %i[add_sap add_sdp add_aap add_adp]
    MOD_POINT_LIST = MOD_POINT_ADD_LIST + MOD_POINT_BASE_LIST

    @@condition_base_proc = []
    @@condition_add_proc = []
    @@combine_param = []
    # バリデーションの設定
    Sequel::Model.plugin :validation_class_methods

    # インサート時の前処理
    before_create do
      self.created_at = Time.now.utc
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
      # self.condition
      # self.condition
    end

    # アップデート後の後理処
    after_save do
      Unlight::CombineCase.refresh_case_version
      Unlight::CombineCase.cache_store.delete("weapon_card:cond:#{id}")
    end

    # 全体データバージョンを返す
    def self.case_version
      ret = cache_store.get('CombineCaseVersion')
      unless ret
        ret = refresh_case_version
        cache_store.set('CombineCaseVersion', ret)
      end
      ret
    end

    # 全体データバージョンを更新（管理ツールが使う）
    def self.refresh_case_version
      m = Unlight::CombineCase.order(:updated_at).last
      if m
        cache_store.set('CombineCaseVersion', m.version)
        m.version
      else
        0
      end
    end

    # バージョン情報(３ヶ月で循環するのでそれ以上クライアント側で保持してはいけない)
    def version
      updated_at.to_i % MODEL_CACHE_INT
    end

    # 合成を行う。変更後のweaon_idと変化値をハッシュで返す
    def self.combine(base_id, add_id_list, case_list)
      # ベースに適応するかチェック
      ok = {}
      # 排他条件順に集める
      case_list.each do |c|
        if c.check?(base_id, add_id_list)
          ok[c.limited] ||= []
          ok[c.limited] << c
        end
      end
      # 排他の条件から優先度の高いものを選ぶ
      list = {}
      ok.each_value do |o|
        max_priority = 0
        o.each do |c|
          list[c.limited] ||= []
          # 優先順があればそれのみ突っ込む
          if max_priority < c.priority
            list[c.limited] = []
            list[c.limited] << c
            max_priority = c.priority
          elsif max_priority == c.priority
            list[c.limited] << c
          end
        end
      end
      ret = []
      # 排他条件が重なるものが複数あるならば一つ選ぶ()
      list.each do |i, r|
        # 排他0はすべて重複、またはリストが1つならそのまま追加
        if i.zero? || r.size < 2
          ret += r
        else
          c = choose_one(r)
        end
        ret << c if c
      end
      get_update_param_hash(ret)
    end

    # 更新パラメータをまとめて返す
    def self.get_update_param_hash(r)
      ret = {}
      r.each do |cc|
        ret = ret.merge(cc.get_result_combined_param) do |k, old, new|
          # ポイントならば合算してしまう
          if MOD_POINT_LIST.include?(k)
            new + old
          else
            new
          end
        end
      end
      ret
    end

    # 確率の重みから特定の値を引く
    def self.choose_one(set)
      prob = 0
      prob_list = Array.new(set.size) { 0 }
      set.each_with_index do |s, i|
        prob_list[i] = prob
        prob += s.pow
      end
      ret = false
      prob = 100 if prob < 100
      rand = rand(prob)
      prob_list.reverse.each_with_index do |c, i|
        if rand > c
          ret = (prob_list.length - 1) - i
          break
        end
      end
      # p set[ret]
      ret ? set[ret] : false
    end

    # 条件が適合するか
    def check?(base_id, add_id_list)
      add_list_used = Array.new(add_id_list.size) { false }
      base_cond = get_condition_base_proc
      add_cond = get_condition_add_proc
      ret = base_cond.call(base_id)
      if ret
        add_cond.each do |ac|
          add_id_list.each_with_index do |a_id, i|
            ret = false
            r = ac.call(a_id) unless add_list_used[i]
            if r
              add_list_used[i] = true
              ret = r
              break
            end
          end
          break unless ret
        end
      end
      ret ? add_list_used : false
    end

    # 条件を取り出す
    def condition
      ret = CombineCase.cache_store.get("combine_case:cond:#{id}")
      unless ret
        ret = { base: [], add: [[]] }
        ret = ret.merge(eval(requirement.tr('|', ','))) unless requirement.empty?
        CombineCase.cache_store.set("combine_case:cond:#{id}", ret)
        @@condition_base_proc[id] = nil
        @@condition_add_proc[id] = nil
      end
      ret
    end

    def get_range_judge_proc(c)
      if c.instance_of?(Range)
        proc { |base| c.include?(base) }
      else
        proc { |base| c == base }
      end
    end

    # baseアイテムの条件を取り出すことが出来る
    def get_condition_base_proc
      return @@condition_base_proc[id] if @@condition_base_proc[id]

      cond_set = condition[:base].map do |c|
        get_range_judge_proc(c)
      end
      @@condition_base_proc[id] = proc do |base|
        ret = false
        cond_set.each do |prc|
          r = prc.call(base)
          ret = true if r
        end
        ret = true if cond_set.empty?
        ret
      end
      @@condition_base_proc[id]
    end

    # baseアイテムの条件を取り出すことが出来る
    def get_condition_add_proc
      return @@condition_add_proc[id] if @@condition_add_proc[id]

      @@condition_add_proc[id] = []
      condition[:add].each do |c|
        set = c.map do |cc|
          get_range_judge_proc(cc)
        end
        set << proc { |_base| true } if c.empty?
        @@condition_add_proc[id] << proc do |base|
          rt = false
          set.each do |prc|
            r = prc.call(base)
            rt = true if r
          end
          rt
        end
      end
      @@condition_add_proc[id]
    end

    # 変更パラメータリスト
    def get_result_combined_param
      ret = {}
      ret = method(MOD_LIST[mod_type]).call(*get_mod_args) if mod_type.positive?
      ret[:new_weapon_id] = combined_w_id if combined_w_id.positive?
      ret
    end

    # mod の引数をとる
    def get_mod_args
      return @@combine_param[id] if @@combine_param[id]

      ret = []
      mod_args.split('|').each do |c|
        if c[0] == ':'
          ret << c[1..].to_sym
        else
          ret << c.to_i
        end
      end
      @@combine_param[id] = ret
      ret
    end

    # 0
    def add_point(t, n)
      { t => n }
    end

    # 1
    def add_point_rnd(t, min, max)
      { t => rand(max) + min }
    end

    def shift_point_rnd(list, t, n)
      l = list.clone
      l.delete(t)
      ret = { t => -n }
      n.times do |_i|
        r = rand(l.size)
        ret[l[r]] ||= 0
        ret[l[r]] += 1
      end
      ret
    end

    # 2
    def shift_base_point_rnd(t, n)
      shift_point_rnd(MOD_POINT_BASE_LIST, t, n)
    end

    # 3
    def shift_add_point_rnd(t, n)
      shift_point_rnd(MOD_POINT_ADD_LIST, t, n)
    end

    # 4
    def shift_base_point(f, t, n)
      { f => -n, t => n }
    end

    # 5
    def shift_add_point(f, t, n)
      shift_base_point(f, t, n)
    end

    # 6
    def set_max(t, n)
      { :set => true, t => n }
    end

    # 7
    def set_passive(n)
      { set: true, passive_id: n }
    end

    # 9
    def change_weapon(t, n)
      ret = shift_point_rnd(MOD_POINT_BASE_LIST, t, n) # パラメータが変更されるようシフト
      # 初期値が必要なものをセット
      ret[:base_max] = COMB_BASE_TOTAL_MAX
      ret[:add_max] = COMB_ADD_TOTAL_MAX
      ret
    end
  end
end

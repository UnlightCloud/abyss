# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # 渦ダメージログクラス
  class ProfoundLog < Sequel::Model
    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods

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

    # ダメージ取得済みチェックIDキャッシュ保存時間(2時間)
    NOW_DMG_CHECKED_LAST_ID_CACHE_TIME = 60 * 60 * 2

    # ログの保存
    def self.set_damage(prf_id, a_id, a_name, c_no, dmg, b_name = '', atk_chara = 0)
      ret = ProfoundLog.new do |pl|
        pl.profound_id   = prf_id
        pl.avatar_id     = a_id
        pl.avatar_name   = a_name
        pl.chara_no      = c_no
        pl.boss_name     = b_name
        pl.damage        = dmg
        pl.atk_charactor = atk_chara
        pl.save_changes
      end
      CACHE.set("prf_log_nowdmg_#{a_id}_#{prf_id}", ret.id, NOW_DMG_CHECKED_LAST_ID_CACHE_TIME)
      CACHE.delete("prf_log_chara_ranking_#{prf_id}") # キャラランキングのキャッシュを消す
      ret
    end

    # Duel開始時のBossのダメージを取得(avatar_idが0の場合、Boss回復)
    def self.get_start_boss_damage(prf_id)
      dmg = [0, 0, 0]
      id  = 0
      list = ProfoundLog.where(profound_id: prf_id).order(:id).all
      list.each do |log|
        if log.avatar_id.zero?
          dmg[log.chara_no] -= log.damage
        else
          dmg[log.chara_no] += log.damage
        end
        id = log.id
      end
      [dmg, id]
    end

    # ダメージをマイナスで保存しないとだめだろ。
    # 総ダメージを取得
    def self.get_all_damage(prf_id)
      dmg = ProfoundLog.where(profound_id: prf_id)
                       .select_append { sum(damage).as(sum_damage) }
                       .where { avatar_id.positive? }.all.first
      heal = ProfoundLog.where(profound_id: prf_id, avatar_id: 0)
                        .select_append { sum(damage).as(sum_damage) }.all.first
      add_dmg = dmg && dmg[:sum_damage] ? dmg[:sum_damage] : 0
      add_heal = heal && heal[:sum_damage] ? heal[:sum_damage] : 0
      add_dmg - add_heal
    end

    # 現在ダメージを取得
    def self.get_now_damage(a_id, prf_id, view_start_dmg = 0, now_dmg = 0)
      log_data = []
      last_id = CACHE.get("prf_log_nowdmg_#{a_id}_#{prf_id}")
      last_id = 0 if last_id.nil? || now_dmg.zero?
      damage = last_id.zero? ? 0 : now_dmg
      log_set = (damage == now_dmg)
      name_view = false
      list = ProfoundLog.where(profound_id: prf_id).where { id > last_id }.order(:id).all
      list.each do |log|
        log_set = true if damage == now_dmg
        if log.avatar_id.zero?
          damage -= log.damage
        else
          damage += log.damage
        end
        name_view = true if name_view == false && damage > view_start_dmg
        if log.id > last_id && log_set && log.avatar_id != a_id
          log_data << { log:, name_view: true }
          last_id = log.id
        end
      end
      CACHE.set("prf_log_nowdmg_#{a_id}_#{prf_id}", last_id, NOW_DMG_CHECKED_LAST_ID_CACHE_TIME)
      ret = damage
      [ret, log_data]
    end

    # ダメージログを取得
    def self.get_profound_damage_log(prf_id, a_id, p_log_id = 0)
      ProfoundLog.where(profound_id: prf_id).where { id > p_log_id }.exclude(avatar_id: a_id).order(:id).all
    end

    # キャラランキングを取ってくる（デフォルトは5位まで）
    def self.get_chara_ranking(prf_id, rank_limit = 5)
      ret = CACHE.get("prf_log_chara_ranking_#{prf_id}")
      unless ret
        ret = ProfoundLog.where(profound_id: prf_id)
                         .where { avatar_id.positive? }
                         .select_group(:atk_charactor)
                         .select_append { sum(damage).as(sum_damage) }
                         .order(Sequel.desc(:sum_damage))
                         .limit(rank_limit)
                         .all
        CACHE.set("prf_log_chara_ranking_#{prf_id}", ret, NOW_DMG_CHECKED_LAST_ID_CACHE_TIME)
      end
      ret
    end

    # キャラランキングを取ってくる（デフォルトは5位まで）
    def self.get_chara_ranking_no_set(prf_id, rank_limit = 5)
      ProfoundLog.get_chara_ranking(prf_id, rank_limit).map(&:atk_charactor)
    end
  end
end

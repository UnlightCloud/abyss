# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # アバターパーツクラス
  class AvatarPart < Sequel::Model
    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods
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

    # アップデート後の後理処
    after_save do
      Unlight::AvatarPart.refresh_data_version
    end

    # 全体データバージョンを返す
    def self.data_version
      ret = cache_store.get('AvatarPartVersion')
      unless ret
        ret = refresh_data_version
        cache_store.set('AvatarPartVersion', ret)
      end
      ret
    end

    # 全体データバージョンを更新（管理ツールが使う）
    def self.refresh_data_version
      m = Unlight::AvatarPart.order(:updated_at).last
      if m
        cache_store.set('AvatarPartVersion', m.version)
      end
      if m
        m.version
      else
        0
      end
    end

    # バージョン情報(３ヶ月で循環するのでそれ以上クライアント側で保持してはいけない)
    def version
      updated_at.to_i % MODEL_CACHE_INT
    end

    # パラメータをCSVのデータで返す
    def to_client
      [
        id,
        name || '',
        image_extract || '',
        parts_type || 0,
        color || 0,
        offset_x || 0,
        offset_y || 0,
        offset_scale || 0,
        power_type || 0,
        power || 0,
        duration || 0,
        trans_caption || ''
      ]
    end

    def image_extract
      image.gsub(/\+dummy_.{1,3}/, '')
    end

    # パーツを装備する
    def attach(a)
      @avatar = a
      if PART_EFFECTS[power_type]
        send(PART_EFFECTS[power_type], power, true)
      end
    end

    # パーツを装備から外す
    def detach(a)
      @avatar = a
      if PART_EFFECTS[power_type]
        send(PART_EFFECTS[power_type], power, false)
      end
      @avatar = nil
    end

    # パラメータの変更点をまとめて返す
    def self.all_params_check(parts_set)
      ret = {}
      ret[:recovery_interval=] = Unlight::AVATAR_RECOVERY_SEC
      ret[:quest_inventory_max=] = Unlight::QUEST_MAX
      ret[:exp_pow=] = 100
      ret[:gem_pow=] = 100
      ret[:quest_find_pow=] = 100

      parts_set.each do |part|
        case part.power_type
        when PART_EFFECTS.index(:shorten_recovery_time)
          ret[:recovery_interval=] -= (part.power * 60)
          # もし60秒よりみじかかったら60秒
          ret[:recovery_interval=] = 60 if ret[:recovery_interval=] < 60
        when PART_EFFECTS.index(:increase_quest_inventory_max)
          ret[:quest_inventory_max=] += part.power
        when PART_EFFECTS.index(:multiply_exp_pow)
          ret[:exp_pow=] += part.power
        when PART_EFFECTS.index(:multiply_gem_pow)
          ret[:gem_pow=] += part.power
        when PART_EFFECTS.index(:shorten_quest_find_time)
          ret[:quest_find_pow=] -= part.power
        end
      end
      ret
    end

    # アイテムの効果、使用関数
    PART_EFFECTS = [
      nil,
      :shorten_recovery_time,        # AP回復時間短縮           1 POWは秒数
      :increase_quest_inventory_max, # クエストインベントリ増加 2
      :multiply_exp_pow,             # EXP増加                  3
      :multiply_gem_pow,             # GEM増加                  4
      :shorten_quest_find_time # クエストゲット時間短縮
    ]

    # AP回復時間を短くする
    def shorten_recovery_time(v, attached = true)
      if @avatar
        num = attached ? (-1 * v) : v
        @avatar.recovery_interval += num * 60
        @avatar.recovery_interval  = Unlight::AVATAR_RECOVERY_SEC if @avatar.recovery_interval > Unlight::AVATAR_RECOVERY_SEC # 元のMAXより多かったらMAX
        @avatar.recovery_interval = 60 if @avatar.recovery_interval < 60
        @avatar.save_changes
        @avatar.energy_recovery_check(true) # 現在リカバリーが発生するかのチェック
        @avatar.update_recovery_interval_event if @avatar.event
      end
    end

    # クエストの探索数のMAX数を増やす
    def increase_quest_inventory_max(v, attached = true)
      if @avatar
        num = attached ? v : (-1 * v)
        @avatar.quest_inventory_max += num
        @avatar.save_changes
        @avatar.update_quest_inventory_max_event if @avatar.event
      end
    end

    # EXPの倍率を増やす
    def multiply_exp_pow(v, attached = true)
      if @avatar
        num = attached ? v : (-1 * v)
        @avatar.exp_pow += num
        @avatar.save_changes
        @avatar.update_exp_pow_event if @avatar.event
      end
    end

    # GEMの倍率を増やす
    def multiply_gem_pow(v, attached = true)
      if @avatar
        num = attached ? v : (-1 * v)
        @avatar.gem_pow += num
        @avatar.save_changes
        @avatar.update_gem_pow_event if @avatar.event
      end
    end

    # クエスト時間をゲット時間を短縮
    def shorten_quest_find_time(v, attached = true)
      if @avatar
        num = attached ? (-1 * v) : v
        @avatar.quest_find_pow += num
        @avatar.quest_find_pow  = 100 if @avatar.quest_find_pow > 100 # 元のMAXより多かったらMAX
        @avatar.save_changes
        @avatar.update_quest_find_pow_event if @avatar.event
      end
    end

    def trans_caption
      if caption
        caption.gsub('__POW__', power.to_s)
      else
        ''
      end
    end
  end
end

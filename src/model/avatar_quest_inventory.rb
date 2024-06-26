# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # アバターの保持クエスト
  class AvatarQuestInventory < Sequel::Model
    # 他クラスのアソシエーション
    many_to_one :avatar               # アバターに複数所持される
    many_to_one :quest                # クエストに複数所持される

    plugin :validation_class_methods
    plugin :hook_class_methods

    def clear_land(no)
      self.progress |= (1 << no)
      save_changes
    end

    def land_cleared?(no)
      (self.progress & (1 << no)).positive?
    end

    def clear_all(succ = true)
      if succ
        self.status = QS_SOLVED
      else
        self.status = QS_FAILED
      end
      self.before_avatar_id = avatar_id
      self.avatar_id = 0
      SERVER_LOG.info("QUEST_INV: [clear_all]inv_id:#{id},succ #{succ}")
      save_changes
    end

    def get_damage_set
      [hp0, hp1, hp2]
    end

    # キャラクタのダメージ量をセットする
    def set_damage_set(set)
      self.hp0 = set[0] if set[0]
      self.hp1 = set[1] if set[1]
      self.hp2 = set[2] if set[2]
      save_changes
    end

    def restart_quest
      self.progress = 0
      save_changes
    end

    # キャラクタの回復量をセットする
    def damage_heal(set)
      if set[0]
        self.hp0 = hp0 - set[0]
        self.hp0 = 0 if hp0.negative?
      end
      if set[1]
        self.hp1 = hp1 - set[1]
        self.hp1 = 0 if hp1.negative?
      end
      if set[2]
        self.hp2 = hp2 - set[2]
        self.hp2 = 0 if hp2.negative?
      end
      save_changes
    end

    def damaged?
      refresh
      (hp0 + hp1 + hp2).positive?
    end

    # 見つかる時間を保存
    def set_find_time(time, pow = 100)
      if QFT_SET[time]
        self.find_at = Time.now.utc + QFT_SET[time] * pow / 100
      else
        self.find_at = Time.now.utc + QFT_SET[10] * pow / 100
      end
      save_changes
    end

    # 発見されたか？
    def quest_find?
      ret = Time.now.utc > find_at
      if ret
        self.status = QS_NEW
        save_changes
      end
      ret
    end

    # 発見時間を分単位で進める（目標時間を縮める）
    def shorten_find_time(min)
      self.find_at = find_at - (min * 60)
      save_changes
    end

    # 別のアバターに送る
    def send_avatar(a_id)
      self.before_avatar_id = avatar_id
      self.avatar_id = a_id
      self.status = QS_PRESENTED
      save_changes
    end

    def unsolved?
      status == QS_UNSOLVE || status == QS_NEW || status == QS_PRESENTED
    end

    def presented?
      avatar_id != before_avatar_id
    end

    # インサート時の前処理
    before_create do
      self.created_at = Time.now.utc
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
    end
  end
end

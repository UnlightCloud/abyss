# Unlight
# Copyright(c)2019 CPA
# This software is released under the MIT License.
# http://opensource.org/licenses/mit-license.php

module Unlight
  # キャラクター本体のデータ
  class Charactor < Sequel::Model
    # プラグインの設定
    plugin :validation_class_methods
    plugin :hook_class_methods
    plugin :caching, CACHE, ignore_exceptions: true

    # バリデーションの設定
    Sequel::Model.plugin :validation_class_methods

    def self.initialize_charactor_param
      @@chara_attribute_set = []
      Charactor.all.each do |c|
        @@chara_attribute_set[c.id] = c.chara_attribute if c.chara_attribute
      end
    end

    def self.attribute(id)
      @@chara_attribute_set[id].split(',') if @@chara_attribute_set[id]
    end

    # インサート時の前処理
    before_create do
      self.created_at = Time.now.utc
    end

    # インサートとアップデート時の前処理
    before_save do
      self.updated_at = Time.now.utc
    end

    # データをとる
    def to_client
      [
        id,
        name || '',
        lobby_image || '',
        chara_voice || '',
        parent_id || 0
      ]
    end

    initialize_charactor_param
  end
end

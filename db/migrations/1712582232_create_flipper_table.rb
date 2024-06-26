# frozen_string_literal: true

Sequel.migration do
  transaction
  up do
    create_table :flipper_features do |_t|
      String :key, primary_key: true, null: false
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end

    create_table :flipper_gates do |_t|
      String :feature_key, null: false
      String :key, null: false
      String :value # NOTE: MySQL not support index on TEXT column
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      primary_key %i[feature_key key value], unique: true
    end
  end

  down do
    def down
      drop_table :flipper_gates
      drop_table :flipper_features
    end
  end
end

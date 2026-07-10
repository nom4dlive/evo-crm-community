class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.bigint   :account_id,            null: false
      t.bigint   :plan_id,               null: false
      t.string   :billing_cycle,         null: false, default: "monthly"  # monthly/annual
      t.string   :status,                null: false, default: "trial"    # trial/active/past_due/canceled
      t.datetime :trial_ends_at
      t.date     :current_period_start
      t.date     :current_period_end
      t.datetime :grace_period_ends_at
      t.datetime :canceled_at

      t.timestamps
    end

    add_index :subscriptions, :account_id
    add_index :subscriptions, :plan_id
    add_index :subscriptions, :status
    add_index :subscriptions, [:account_id, :status], name: "index_subscriptions_on_account_and_status"
    add_foreign_key :subscriptions, :plans
  end
end

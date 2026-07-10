class CreatePlans < ActiveRecord::Migration[7.1]
  def change
    create_table :plans do |t|
      t.string  :name,                  null: false
      t.string  :slug,                  null: false
      t.string  :tier,                  null: false  # free/starter/pro/enterprise
      t.integer :price_monthly_cents,   null: false, default: 0
      t.integer :price_annual_cents,    null: false, default: 0
      t.decimal :annual_discount_pct,   precision: 5, scale: 2, default: 0
      t.integer :limit_instances,       default: 1
      t.integer :limit_agents,          default: 1
      t.integer :limit_messages_per_month
      t.boolean :active,                null: false, default: true

      t.timestamps
    end

    add_index :plans, :slug, unique: true
    add_index :plans, :tier
    add_index :plans, :active
  end
end

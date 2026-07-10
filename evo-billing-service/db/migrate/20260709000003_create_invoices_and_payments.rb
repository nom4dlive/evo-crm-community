class CreateInvoicesAndPayments < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.bigint   :account_id,       null: false
      t.bigint   :subscription_id
      t.string   :status,           null: false, default: "draft"  # draft/open/paid/void
      t.integer  :subtotal_cents,   null: false, default: 0
      t.integer  :total_cents,      null: false, default: 0
      t.string   :currency,         null: false, default: "BRL"
      t.date     :due_date
      t.datetime :paid_at

      t.timestamps
    end

    add_index :invoices, :account_id
    add_index :invoices, :subscription_id
    add_index :invoices, :status
    add_foreign_key :invoices, :subscriptions

    create_table :invoice_items do |t|
      t.bigint   :invoice_id,         null: false
      t.string   :description,        null: false
      t.integer  :quantity,           null: false, default: 1
      t.integer  :unit_price_cents,   null: false, default: 0
      t.integer  :total_cents,        null: false, default: 0

      t.timestamps
    end

    add_index :invoice_items, :invoice_id
    add_foreign_key :invoice_items, :invoices

    create_table :payments do |t|
      t.bigint   :account_id,         null: false
      t.bigint   :invoice_id
      t.string   :asaas_payment_id,   index: { unique: true }
      t.string   :method,             null: false  # pix/boleto/credit_card
      t.string   :status,             null: false, default: "pending"  # pending/confirmed/failed/refunded
      t.integer  :amount_cents,       null: false, default: 0
      t.datetime :paid_at

      t.timestamps
    end

    add_index :payments, :account_id
    add_index :payments, :invoice_id
    add_index :payments, :status
    add_foreign_key :payments, :invoices
  end
end

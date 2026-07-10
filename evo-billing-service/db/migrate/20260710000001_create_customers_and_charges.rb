class CreateCustomersAndCharges < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.bigint :account_id, null: false
      t.integer :contact_id, null: false
      t.string :asaas_customer_id, null: false
      t.string :name
      t.string :cpf_cnpj
      t.string :email
      t.string :phone

      t.timestamps
    end

    add_index :customers, :account_id
    add_index :customers, :contact_id
    add_index :customers, :asaas_customer_id, unique: true
    add_index :customers, [:account_id, :contact_id], unique: true, name: "index_customers_on_account_and_contact"

    create_table :contact_charges do |t|
      t.bigint :account_id, null: false
      t.bigint :customer_id, null: false
      t.string :description
      t.integer :amount_cents, null: false
      t.date :due_date, null: false
      t.string :billing_method, null: false # pix/boleto/credit_card
      t.string :status, null: false, default: "pending" # pending/confirmed/overdue/canceled
      t.string :asaas_charge_id, null: false
      t.string :payment_link

      t.timestamps
    end

    add_index :contact_charges, :account_id
    add_index :contact_charges, :customer_id
    add_index :contact_charges, :status
    add_index :contact_charges, :asaas_charge_id, unique: true
    add_foreign_key :contact_charges, :customers
  end
end

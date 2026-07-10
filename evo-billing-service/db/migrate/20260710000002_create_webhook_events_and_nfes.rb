class CreateWebhookEventsAndNfes < ActiveRecord::Migration[7.1]
  def change
    create_table :asaas_webhook_events do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.boolean :processed, null: false, default: false
      t.datetime :processed_at

      t.datetime :created_at, null: false
    end

    add_index :asaas_webhook_events, :event_id, unique: true

    create_table :nfe_documents do |t|
      t.bigint :account_id, null: false
      t.bigint :payment_id
      t.bigint :contact_charge_id
      t.string :asaas_nfe_id, null: false
      t.string :nfe_number
      t.string :pdf_url
      t.string :xml_url
      t.string :nfe_error
      t.datetime :issued_at

      t.timestamps
    end

    add_index :nfe_documents, :account_id
    add_index :nfe_documents, :payment_id
    add_index :nfe_documents, :contact_charge_id
    add_index :nfe_documents, :asaas_nfe_id, unique: true
    add_foreign_key :nfe_documents, :payments
    add_foreign_key :nfe_documents, :contact_charges
  end
end

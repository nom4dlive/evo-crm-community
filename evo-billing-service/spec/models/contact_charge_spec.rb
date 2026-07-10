require "rails_helper"

RSpec.describe ContactCharge, type: :model do
  before do
    Current.account_id = 1
    Current.user_id    = 100
    Current.role       = "admin"
  end

  after { Current.reset }

  let!(:customer) do
    Customer.create!(
      account_id: 1, contact_id: 1,
      asaas_customer_id: "cus_cc_test", cpf_cnpj: "12345678901"
    )
  end

  describe "validations" do
    it "is valid with all required attributes" do
      charge = ContactCharge.new(
        account_id: 1, customer: customer,
        description: "Consulta", amount_cents: 15000,
        due_date: Date.tomorrow, billing_method: "pix",
        asaas_charge_id: "pay_1", status: "pending"
      )
      expect(charge).to be_valid
    end

    it "requires amount_cents > 0" do
      charge = ContactCharge.new(
        account_id: 1, customer: customer,
        description: "Consulta", amount_cents: 0,
        due_date: Date.tomorrow, billing_method: "pix",
        asaas_charge_id: "pay_val1", status: "pending"
      )
      expect(charge).not_to be_valid
    end

    it "validates billing_method inclusion" do
      charge = ContactCharge.new(
        account_id: 1, customer: customer,
        description: "Test", amount_cents: 100,
        due_date: Date.tomorrow, billing_method: "cash",
        asaas_charge_id: "pay_val2", status: "pending"
      )
      expect(charge).not_to be_valid
    end
  end

  describe "state transitions" do
    let!(:charge) do
      ContactCharge.create!(
        account_id: 1, customer: customer,
        description: "Test", amount_cents: 10000,
        due_date: Date.tomorrow, billing_method: "pix",
        asaas_charge_id: "pay_state", status: "pending"
      )
    end

    it "confirms a charge" do
      charge.confirm!
      expect(charge.reload.status).to eq("confirmed")
    end

    it "marks overdue" do
      charge.mark_overdue!
      expect(charge.reload.status).to eq("overdue")
    end

    it "cancels a charge" do
      charge.cancel!
      expect(charge.reload.status).to eq("canceled")
    end
  end

  describe "tenant scoping" do
    it "scopes by account_id" do
      ContactCharge.create!(
        account_id: 1, customer: customer,
        description: "T1", amount_cents: 5000,
        due_date: Date.tomorrow, billing_method: "boleto",
        asaas_charge_id: "pay_t1", status: "pending"
      )

      Current.account_id = 2
      expect(ContactCharge.count).to eq(0)

      Current.account_id = 1
      expect(ContactCharge.count).to eq(1)
    end
  end
end

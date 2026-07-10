require "rails_helper"

RSpec.describe Customer, type: :model do
  before do
    Current.account_id = 1
    Current.user_id    = 100
    Current.role       = "admin"
  end

  after { Current.reset }

  describe "validations" do
    it "requires account_id" do
      customer = Customer.new(contact_id: 1, asaas_customer_id: "cus_1", cpf_cnpj: "12345678901")
      customer.account_id = nil
      Current.account_id = nil
      expect { customer.save! }.to raise_error(TenantContextMissing)
    end

    it "requires contact_id" do
      customer = Customer.new(account_id: 1, asaas_customer_id: "cus_2", cpf_cnpj: "12345678901")
      expect(customer).not_to be_valid
      expect(customer.errors[:contact_id]).to include("can't be blank")
    end

    it "requires asaas_customer_id" do
      customer = Customer.new(account_id: 1, contact_id: 1, cpf_cnpj: "12345678901")
      expect(customer).not_to be_valid
      expect(customer.errors[:asaas_customer_id]).to include("can't be blank")
    end

    it "requires cpf_cnpj" do
      customer = Customer.new(account_id: 1, contact_id: 1, asaas_customer_id: "cus_3")
      expect(customer).not_to be_valid
      expect(customer.errors[:cpf_cnpj]).to include("can't be blank")
    end

    it "enforces unique asaas_customer_id" do
      Customer.create!(account_id: 1, contact_id: 1, asaas_customer_id: "cus_unique", cpf_cnpj: "11111111111")
      dup = Customer.new(account_id: 1, contact_id: 2, asaas_customer_id: "cus_unique", cpf_cnpj: "22222222222")
      expect(dup).not_to be_valid
      expect(dup.errors[:asaas_customer_id]).to include("has already been taken")
    end
  end

  describe "tenant scoping" do
    it "scopes queries by Current.account_id" do
      Customer.create!(account_id: 1, contact_id: 1, asaas_customer_id: "cus_t1", cpf_cnpj: "11111111111")
      Customer.unscoped.create!(account_id: 2, contact_id: 2, asaas_customer_id: "cus_t2", cpf_cnpj: "22222222222")

      expect(Customer.count).to eq(1)
      expect(Customer.first.asaas_customer_id).to eq("cus_t1")
    end
  end

  describe "associations" do
    it "has many contact_charges" do
      customer = Customer.create!(account_id: 1, contact_id: 1, asaas_customer_id: "cus_assoc", cpf_cnpj: "33333333333")
      expect(customer).to respond_to(:contact_charges)
    end
  end
end

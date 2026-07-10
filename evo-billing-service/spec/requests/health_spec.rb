require "rails_helper"

RSpec.describe "Health", type: :request do
  describe "GET /health" do
    it "returns 200 with service status — no auth required" do
      get "/health"
      puts "RESPONSE BODY: #{response.body}" if response.status != 200

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body["service"]).to eq("evo-billing-service")
    end
  end
end

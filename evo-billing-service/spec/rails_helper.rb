require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rspec/rails"
require "factory_bot_rails"
require "shoulda/matchers"
require "webmock/rspec"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable built-in Rails transactional fixtures for database isolation
  config.use_transactional_fixtures = true
  
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include AuthHelpers, type: :request

  # Reset Current attributes after each example
  config.after(:each) do
    Current.reset
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Block all external HTTP by default — Ref: Spec P2-AC-12
WebMock.disable_net_connect!(allow_localhost: true)

# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

require "active_record"

begin
  require "simplecov"
  SimpleCov.start do
    skip ["/spec/"]
  end
rescue LoadError
end

Bundler.require(:default, :test)

ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")

require_relative "../lib/support_table_data"

SupportTableData.data_directory = File.join(__dir__, "data")

require_relative "models"

RSpec.configure do |config|
  config.warnings = true
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  config.before do
    Thing.delete_all
    Hue.delete_all
    Group.delete_all
    Color.delete_all
    Shape.delete_all
  end
end

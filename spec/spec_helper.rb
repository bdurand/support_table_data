require "bundler/setup"

require "active_record"

ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")

require_relative "../lib/support_table_data"
require_relative "../lib/support_table_data/documentation"

SupportTableData.data_directory = File.join(__dir__, "data")

require_relative "models"

RSpec.configure do |config|
  config.order = :random

  config.before do
    Thing.delete_all
    Hue.delete_all
    Group.delete_all
    Color.delete_all
  end
end

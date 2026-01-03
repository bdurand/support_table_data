# frozen_string_literal: true

module SupportTableData
  class Railtie < Rails::Railtie
    config.support_table_data_directory = "db/support_tables"

    initializer "support_table_data" do |app|
      SupportTableData.data_directory ||= app.config.support_table_data_directory
    end

    rake_tasks do
      load File.expand_path("../tasks/support_table_data.rake", __dir__)
    end
  end
end

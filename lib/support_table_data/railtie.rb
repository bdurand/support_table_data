# frozen_string_literal: true

module SupportTableData
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/support_table_data.rake", __dir__)
    end
  end
end

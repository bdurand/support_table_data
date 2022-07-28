# frozen_string_literal: true

if defined?(Rails::Railtie)
  module SupportTableData
    class Railtie < Rails::Railtie
      configure do
        SupportTableData.data_directory = Rails.root.join("db", "support_tables").to_s
      end
    end
  end
end

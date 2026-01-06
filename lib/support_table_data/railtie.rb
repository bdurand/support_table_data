# frozen_string_literal: true

module SupportTableData
  class Railtie < Rails::Railtie
    unless config.respond_to?(:support_table) && config.support_table
      config.support_table = ActiveSupport::OrderedOptions.new
    end

    config.support_table.data_directory ||= "db/support_tables"
    config.support_table.auto_sync ||= true

    initializer "support_table_data" do |app|
      SupportTableData.data_directory ||= app.root.join(app.config.support_table&.data_directory).to_s
    end

    rake_tasks do |app|
      load File.expand_path("../tasks/support_table_data.rake", __dir__)

      if app.config.support_table.auto_sync
        ["db:seed", "db:seed:replant", "db:prepare", "db:test:prepare", "db:fixtures:load"].each do |task_name|
          next unless Rake::Task.task_defined?(task_name)

          Rake::Task[task_name].enhance do
            Rake::Task["support_table_data:sync"].invoke
          end
        end
      end
    end
  end
end

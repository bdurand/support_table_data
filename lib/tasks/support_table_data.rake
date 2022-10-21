# frozen_string_literal: true

namespace :support_table_data do
  desc "Syncronize data for all models that include SupportTableData."
  task sync: :environment do
    if defined?(Rails)
      unless Rails.config.eager_load
        if defined?(Rails.application.eager_load!)
          Rails.application.eager_load!
        elsif defined?(Rails.autoloaders.zeitwerk_enabled?) && Rails.autoloaders.zeitwerk_enabled?
          Rails.autoloaders.each(&:eager_load)
        else
          warn "Could not eager load models; some support table data may not load"
        end
      end
    end

    SupportTableData.sync_all! do |klass, changes|
      puts "Synchronized support table data for #{klass.name}"
    end
  end
end

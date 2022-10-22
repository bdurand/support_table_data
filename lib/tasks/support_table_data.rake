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

    logger_callback = lambda do |name, started, finished, unique_id, payload|
      klass = payload[:class]
      elapsed_time = finished - started
      message = "Synchronized support table model #{klass.name} in #{(elapsed_time * 1000).round}ms"
      if klass.logger
        klass.logger.info(message)
      else
        puts message
      end
    end

    ActiveSupport::Notifications.subscribed(logger_callback, "support_table_data.sync", monotonic: true) do
      SupportTableData.sync_all!
    end
  end
end

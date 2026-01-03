# frozen_string_literal: true

module SupportTableData
  module Tasks
    module Utils
      class << self
        # Helper for eager loading a Rails application.
        def eager_load!
          return unless defined?(Rails.application.config.eager_load)
          return if Rails.application.config.eager_load

          if defined?(Rails.application.eager_load!)
            Rails.application.eager_load!
          elsif defined?(Rails.autoloaders.zeitwerk_enabled?) && Rails.autoloaders.zeitwerk_enabled?
            Rails.autoloaders.each(&:eager_load)
          else
            raise "Failed to eager load application."
          end
        end

        def model_file_path(klass)
          file_path = "#{klass.name.underscore}.rb"
          model_path = nil

          Rails.application.config.paths["app/models"].each do |path_prefix|
            path = Pathname.new(path_prefix.to_s).join(file_path)
            if path&.file? && path.readable?
              model_path = path
              break
            end
          end

          model_path
        end
      end
    end
  end
end

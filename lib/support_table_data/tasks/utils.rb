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

        # Return all source files for models that include SupportTableData.
        #
        # @param file_path [String, Pathname, nil] Optional file path to filter by.
        # @return [Array<SupportTableData::Documentation::SourceFile>]
        def support_table_sources(file_path = nil)
          file_path = Pathname.new(file_path) if file_path.is_a?(String)
          require file_path.expand_path if file_path

          sources = []

          ActiveRecord::Base.descendants.each do |klass|
            next unless klass.include?(SupportTableData)
            # Skip STI subclasses; only the class that owns the data files gets documented.
            next unless klass.instance_variable_defined?(:@support_table_data_files)
            next if klass.instance_names.empty?

            model_file_path = SupportTableData::Tasks::Utils.model_file_path(klass)
            next unless model_file_path&.file? && model_file_path.readable?

            sources << Documentation::SourceFile.new(klass, model_file_path)
          end

          return sources if file_path.nil?

          resolved_path = Pathname.new(file_path.to_s).expand_path
          sources.select { |source| source.path.expand_path == resolved_path }
        rescue ArgumentError
          []
        end

        # Return RBS file handlers for all support table models.
        #
        # @param file_path [String, Pathname, nil] Optional file path to filter by.
        # @return [Array<SupportTableData::Documentation::RbsFile>]
        def support_table_rbs_files(file_path = nil)
          support_table_sources(file_path).map do |source|
            Documentation::RbsFile.new(source.klass, source.path)
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

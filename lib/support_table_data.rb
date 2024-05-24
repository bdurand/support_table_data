# frozen_string_literal: true

# This concern can be mixed into models that represent static support tables. These are small tables
# that have a limited number of rows, and have values that are often tied to the logic in the code.
#
# The values that should be in support tables can be defined in YAML, JSON, or CSV files. These
# values can then be synced to the database and helper methods can be generated from them.
module SupportTableData
  extend ActiveSupport::Concern

  included do
    # Internal variables used for memoization.
    @support_table_data_files = []
    @support_table_attribute_helpers = {}
    @support_table_instance_names = {}
    @support_table_instance_keys = nil

    # Define the attribute used as the key of the hash in the data files.
    # This should be a value that never changes. By default the key attribute will be the id.
    class_attribute :support_table_key_attribute, instance_accessor: false

    # Define the directory where data files should be loaded from. This value will override the global
    # value set by SupportTableData.data_directory. This is only used if relative paths are passed
    # in to add_support_table_data.
    class_attribute :support_table_data_directory, instance_accessor: false
  end

  class_methods do
    # Synchronize the rows in the table with the values defined in the data files added with
    # `add_support_table_data`. Note that rows will not be deleted if they are no longer in
    # the data files.
    #
    # @return [Array<Hash>] List of saved changes for each record that was created or modified.
    def sync_table_data!
      return unless table_exists?

      key_attribute = (support_table_key_attribute || primary_key).to_s
      canonical_data = support_table_data.each_with_object({}) { |attributes, hash| hash[attributes[key_attribute].to_s] = attributes }
      records = where(key_attribute => canonical_data.keys)
      changes = []

      ActiveSupport::Notifications.instrument("support_table_data.sync", class: self) do
        transaction do
          records.each do |record|
            key = record[key_attribute].to_s
            attributes = canonical_data.delete(key)
            attributes&.each do |name, value|
              record.send(:"#{name}=", value) if record.respond_to?(:"#{name}=", true)
            end
            if record.changed?
              changes << record.changes
              record.save!
            end
          end

          canonical_data.each_value do |attributes|
            record = new
            attributes.each do |name, value|
              record.send(:"#{name}=", value) if record.respond_to?(:"#{name}=", true)
            end
            changes << record.changes
            record.save!
          end
        end
      end

      changes
    end

    # Add a data file that contains the support table data. This method can be called multiple times to
    # load data from multiple files.
    #
    # @param data_file_path [String, Pathname] The path to a YAML, JSON, or CSV file containing data for this model. If
    #   the path is a relative path, then it will be resolved from the either the default directory set for
    #   this model or the global directory set with SupportTableData.data_directory.
    # @return [void]
    def add_support_table_data(data_file_path)
      root_dir = (support_table_data_directory || SupportTableData.data_directory || Dir.pwd)
      @support_table_data_files << File.expand_path(data_file_path, root_dir)
      define_support_table_named_instances
    end

    # Add class methods to get attributes for named instances. The methods will be named
    # like `#{instance_name}_#{attribute_name}`. For example, if the name is "active" and the
    # attribute is "id", then the method will be "active_id" and you can call
    # `Model.active_id` to get the value.
    #
    # @param attributes [String, Symbol] The names of the attributes to add helper methods for.
    # @return [void]
    def named_instance_attribute_helpers(*attributes)
      attributes.flatten.collect(&:to_s).each do |attribute|
        @support_table_attribute_helpers[attribute] = []
      end
      define_support_table_named_instances
    end

    # Get the names of any named instance attribute helpers that have been defined
    # with `named_instance_attribute_helpers`.
    #
    # @return [Array<String>] List of attribute names.
    def support_table_attribute_helpers
      @support_table_attribute_helpers.keys
    end

    # Get the data for the support table from the data files.
    #
    # @return [Array<Hash>] List of attributes for all records in the data files.
    def support_table_data
      data = {}
      key_attribute = (support_table_key_attribute || primary_key).to_s

      @support_table_data_files.each do |data_file_path|
        file_data = support_table_parse_data_file(data_file_path)
        file_data = file_data.values if file_data.is_a?(Hash)
        file_data = Array(file_data).flatten
        file_data.each do |attributes|
          key_value = attributes[key_attribute].to_s
          existing = data[key_value]
          if existing
            existing.merge!(attributes)
          else
            data[key_value] = attributes
          end
        end
      end

      data.values
    end

    # Get the data for a named instances from the data files.
    #
    # @return [Hasn] Hash of named instance attributes.
    def named_instance_data(name)
      data = {}
      name = name.to_s

      @support_table_data_files.each do |data_file_path|
        file_data = support_table_parse_data_file(data_file_path)
        next unless file_data.is_a?(Hash)

        file_data.each do |instance_name, attributes|
          next unless name == instance_name.to_s
          next unless attributes.is_a?(Hash)

          data.merge!(attributes)
        end
      end

      data
    end

    # Get the names of all named instances.
    #
    # @return [Array<String>] List of all instance names.
    def instance_names
      @support_table_instance_names.keys
    end

    # Load a named instance from the database.
    #
    # @param instance_name [String, Symbol] The name of the instance to load as defined in the data files.
    # @return [ActiveRecord::Base] The instance loaded from the database.
    # @raise [ActiveRecord::RecordNotFound] If the instance does not exist.
    def named_instance(instance_name)
      key_attribute = (support_table_key_attribute || primary_key).to_s
      instance_name = instance_name.to_s
      find_by!(key_attribute => @support_table_instance_names[instance_name])
    end

    # Get the key values for all instances loaded from the data files.
    #
    # @return [Array] List of all the key attribute values.
    def instance_keys
      if @support_table_instance_keys.nil?
        key_attribute = (support_table_key_attribute || primary_key).to_s
        values = []
        support_table_data.each do |attributes|
          key_value = attributes[key_attribute]
          instance = new
          instance.send(:"#{key_attribute}=", key_value)
          values << instance.send(key_attribute)
        end
        @support_table_instance_keys = values.uniq
      end
      @support_table_instance_keys
    end

    # Return true if the instance has data being managed from a data file.
    #
    # @return [Boolean]
    def protected_instance?(instance)
      key_attribute = (support_table_key_attribute || primary_key).to_s

      unless defined?(@protected_keys)
        keys = support_table_data.collect { |attributes| attributes[key_attribute].to_s }
        @protected_keys = keys
      end

      @protected_keys.include?(instance[key_attribute].to_s)
    end

    private

    def define_support_table_named_instances
      @support_table_data_files.each do |file_path|
        data = support_table_parse_data_file(file_path)
        next unless data.is_a?(Hash)

        data.each do |name, attributes|
          define_support_table_named_instance_methods(name, attributes)
        end
      end
    end

    def define_support_table_named_instance_methods(name, attributes)
      method_name = name.to_s.freeze
      return if method_name.start_with?("_")

      unless attributes.is_a?(Hash)
        raise ArgumentError.new("Cannot define named instance #{method_name} on #{name}; value must be a Hash")
      end

      unless method_name.match?(/\A[a-z][a-z0-9_]+\z/)
        raise ArgumentError.new("Cannot define named instance #{method_name} on #{name}; name contains illegal characters")
      end

      key_attribute = (support_table_key_attribute || primary_key).to_s
      key_value = attributes[key_attribute]

      unless @support_table_instance_names.include?(method_name)
        define_support_table_instance_helper(method_name, key_attribute, key_value)
        define_support_table_predicates_helper("#{method_name}?", key_attribute, key_value)
        @support_table_instance_names[method_name] = key_value
      end

      if defined?(@support_table_attribute_helpers)
        @support_table_attribute_helpers.each do |attribute_name, defined_methods|
          attribute_method_name = "#{method_name}_#{attribute_name}"
          next if defined_methods.include?(attribute_method_name)

          define_support_table_instance_attribute_helper(attribute_method_name, attributes[attribute_name])
          defined_methods << attribute_method_name
        end
      end
    end

    def define_support_table_instance_helper(method_name, attribute_name, attribute_value)
      if respond_to?(method_name, true)
        raise ArgumentError.new("Could not define support table helper method #{name}.#{method_name} because it is already a defined method")
      end

      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def self.#{method_name}
          find_by!(#{attribute_name}: #{attribute_value.inspect})
        end
      RUBY
    end

    def define_support_table_instance_attribute_helper(method_name, attribute_value)
      if respond_to?(method_name, true)
        raise ArgumentError.new("Could not define support table helper method #{name}.#{method_name} because it is already a defined method")
      end

      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def self.#{method_name}
          #{attribute_value.inspect}.freeze
        end
      RUBY
    end

    def define_support_table_predicates_helper(method_name, attribute_name, attribute_value)
      if method_defined?(method_name) || private_method_defined?(method_name)
        raise ArgumentError.new("Could not define support table helper method #{name}##{method_name} because it is already a defined method")
      end

      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{method_name}
          #{attribute_name} == #{attribute_value.inspect}
        end
      RUBY
    end

    def support_table_parse_data_file(file_path)
      file_data = File.read(file_path)

      extension = file_path.split(".").last&.downcase
      data = []

      case extension
      when "json"
        require "json" unless defined?(JSON)
        data = JSON.parse(file_data)
      when "csv"
        require "csv" unless defined?(CSV)
        CSV.new(file_data, headers: true).each do |row|
          data << row.to_h
        end
      else
        require "yaml" unless defined?(YAML)
        data = YAML.safe_load(file_data)
      end

      data
    end
  end

  class << self
    # Specify the default directory for data files.
    attr_writer :data_directory

    # The directory where data files live by default. If you are running in a Rails environment,
    # then this will be `db/support_tables`. Otherwise, the current working directory will be used.
    #
    # @return [String]
    def data_directory
      if defined?(@data_directory)
        @data_directory
      elsif defined?(Rails.root)
        Rails.root.join("db", "support_tables").to_s
      end
    end

    # Sync all support table classes. Classes must already be loaded in order to be synced.
    #
    # You can pass in a list of classes that you want to ensure are synced. This feature
    # can be used to force load classes that are only loaded at runtime. For instance, if
    # eager loading is turned off for the test environment in a Rails application (which is
    # the default), then there is a good chance that support table models won't be loaded
    # when the test suite is initializing.
    #
    # @param extra_classes [Class] List of classes to force into the detected list of classes to sync.
    # @return [Hash<Class, Array<Hash>] Hash of classes synced with a list of saved changes.
    def sync_all!(*extra_classes)
      changes = {}
      support_table_classes(*extra_classes).each do |klass|
        changes[klass] = klass.sync_table_data!
      end
      changes
    end

    # Return the list of all support table classes in the order they should be loaded.
    # Note that this method relies on the classes already having been loaded by the application.
    # It can return indeterminate results if eager loading is turned off (i.e. development
    # or test mode in a Rails application).
    #
    # If any data files exist in the default data directory, any class name that matches
    # the file name will attempt to be loaded (i.e. "task/statuses.yml" will attempt to
    # load the `Task::Status` class if it exists).
    #
    # You can also pass in a list of classes that you explicitly want to include in the returned list.
    #
    # @param extra_classes [Class] List of extra classes to include in the return list.
    # @return [Array<Class>] List of classes in the order they should be loaded.
    # @api private
    def support_table_classes(*extra_classes)
      classes = []
      extra_classes.flatten.each do |klass|
        unless klass.is_a?(Class) && klass.include?(SupportTableData)
          raise ArgumentError.new("#{klass} does not include SupportTableData")
        end
        classes << klass
      end

      # Eager load any classes defined in the default data directory by guessing class names
      # from the file names.
      if SupportTableData.data_directory && File.exist?(SupportTableData.data_directory) && File.directory?(SupportTableData.data_directory)
        Dir.chdir(SupportTableData.data_directory) { Dir.glob(File.join("**", "*")) }.each do |file_name|
          class_name = file_name.sub(/\.[^.]*/, "").singularize.camelize
          class_name.safe_constantize
        end
      end

      active_record_classes = ActiveRecord::Base.descendants.reject { |klass| klass.name.nil? }
      active_record_classes.sort_by(&:name).each do |klass|
        next unless klass.include?(SupportTableData)
        next if klass.abstract_class?
        next if classes.include?(klass)
        classes << klass
      end

      levels = [classes]
      checked = Set.new
      loop do
        checked << classes
        dependencies = classes.collect { |klass| support_table_dependencies(klass) }.flatten.uniq.sort_by(&:name)
        break if dependencies.empty? || checked.include?(dependencies)
        levels.unshift(dependencies)
        classes = dependencies
      end

      levels.flatten.uniq
    end

    private

    # Extract support table dependencies from the belongs to associations on a class.
    #
    # @return [Array<Class>]
    def support_table_dependencies(klass)
      dependencies = []
      klass.reflections.values.select(&:belongs_to?).each do |reflection|
        if reflection.klass.include?(SupportTableData) && !(reflection.klass <= klass)
          dependencies << reflection.klass
        end
      end
      dependencies
    end
  end

  # Return true if this instance has data being managed from a data file. You can add validation
  # logic using this information if you want to prevent the application from updating protected instances.
  #
  # @return [Boolean]
  def protected_instance?
    self.class.protected_instance?(self)
  end
end

if defined?(Rails::Railtie)
  require_relative "support_table_data/railtie"
end

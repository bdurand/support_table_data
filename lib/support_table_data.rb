# frozen_string_literal: true

# This concern can be mixed into models that represent static support tables. These
# would be small tables that have a limited number of rows and which have values that
# are often tied into logic in the code.
#
# The values that should be in support tables can be defined in YAML, JSON, or CSV files. These
# values can then be synced to the database and helper methods can be generated from them.
module SupportTableData
  extend ActiveSupport::Concern

  module ClassMethods
    # Synchronize the rows in the table with the values defined in the data files added with
    # `add_support_table_data`. Note that rows will not be deleted if they are no longer in
    # the data files. This method should normally be called from a database or seed migration.
    # You should create a new migration any time values in the data files are changed.
    #
    # @return [void]
    def sync_table_data!
      key_attribute = (support_table_key_attribute || :id).to_s
      canonical_data = support_table_data.each_with_object({}) { |attributes, hash| hash[attributes[key_attribute].to_s] = attributes }
      records = where(key_attribute => canonical_data.keys)

      records.each do |record|
        key = record[key_attribute].to_s
        attributes = canonical_data.delete(key)
        attributes&.each do |name, value|
          record.send("#{name}=", value) if record.respond_to?("#{name}=", true)
        end
        record.save! if record.changed?
      end

      canonical_data.each_value do |attributes|
        record = new
        attributes.each do |name, val|
          record.send("#{name}=", val) if record.respond_to?("#{name}=", true)
        end
        record.save!
      end
    end

    # Add a data file the contains the support table data. This method can be called multiple times to
    # load data from multiple files.
    #
    # @param data_file_path [String, Pathname] Path to a YAML, JSON, or CSV file containing data for this model. If
    #   the path is a relative path, then it will be resolved from the either the default directory set for
    #   this model or the global directory set with SupportTableData.data_directory.
    # @return [void]
    def add_support_table_data(data_file_path)
      @support_table_data_files ||= []
      root_dir = (support_table_data_directory || SupportTableData.data_directory || Dir.pwd)
      @support_table_data_files << File.expand_path(data_file_path, root_dir)
      define_support_table_named_instances
    end

    # Load the data for the support table from the data files.
    #
    # @return [Array<Hash>] Merged array of all the support table data.
    def support_table_data
      @support_table_data_files ||= []
      data = {}
      key_attribute = (support_table_key_attribute || :id).to_s

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

    # Get the names for all named instances.
    #
    # @return [Array<String>]
    def instance_names
      @support_table_instance_names ||= Set.new
      @support_table_instance_names.to_a
    end

    # Get the key values for all instances loaded from data files.
    #
    # @return [Array]
    def instance_keys
      unless defined?(@support_table_instance_keys)
        key_attribute = (support_table_key_attribute || :id).to_s
        values = []
        support_table_data.each do |attributes|
          key_value = attributes[key_attribute]
          instance = new
          instance.send("#{key_attribute}=", key_value)
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
      key_attribute = (support_table_key_attribute || :id).to_s

      unless defined?(@protected_keys)
        keys = support_table_data.collect { |attributes| attributes[key_attribute].to_s }
        @protected_keys = keys
      end

      @protected_keys.include?(instance[key_attribute].to_s)
    end

    private

    def define_support_table_named_instances
      @support_table_data_files ||= []
      @support_table_instance_names ||= Set.new
      key_attribute = (support_table_key_attribute || :id).to_s

      @support_table_data_files.each do |file_path|
        data = support_table_parse_data_file(file_path)
        if data.is_a?(Hash)
          data.each do |key, attributes|
            method_name = key.to_s.freeze
            next if method_name.start_with?("_")

            unless attributes.is_a?(Hash)
              raise ArgumentError.new("Cannot define named instance #{method_name} on #{name}; value must be a Hash")
            end

            unless method_name.match?(/\A[a-z][a-z0-9_]+\z/)
              raise ArgumentError.new("Cannot define named instance #{method_name} on #{name}; name contains illegal characters")
            end

            unless @support_table_instance_names.include?(method_name)
              @support_table_instance_names << method_name
              key_value = attributes[key_attribute]
              define_support_table_instance_helper(method_name, key_attribute, key_value)
              define_support_table_predicates_helper("#{method_name}?", key_attribute, key_value)
            end
          end
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

  included do
    # Define the attribute used as the key of the hash in the data files.
    # This should be a value that never changes. By default the key attribute will be the id.
    class_attribute :support_table_key_attribute, instance_accessor: false

    # Define the directory where data files should be loaded from. This value will override the global
    # value set by SupportTableData.data_directory. This is only used if relative paths are passed
    # in to add_support_table_data.
    class_attribute :support_table_data_directory, instance_accessor: false
  end

  class << self
    # Specify the directory where data files live by default.
    attr_writer :data_directory

    # The directory where data files live by default. If you are running in a Rails environment,
    # then this will be `db/support_tables`. Otherwise the current working directory will be used.
    #
    # @return [String]
    def data_directory
      if defined?(@data_directory)
        @data_directory
      elsif defined?(Rails.root)
        Rails.root.join("db", "support_tables").to_s
      end
    end
  end

  # Return true if this instance has data being managed from a data file. You can add validation
  # logic using this information if you want prevent the application from updating protected instances.
  #
  # @return [Boolean]
  def protected_instance?
    self.class.protected_instance?(self)
  end
end

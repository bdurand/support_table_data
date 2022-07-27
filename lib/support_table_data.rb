# frozen_string_literal: true

require "yaml"
require "json"

# This concern can be mixed into models that represent static support tables. These
# would be small tables that have a limited number of rows and which have values that
# are often tied into logic in the code.
#
# The values that should be in support tables is defined in YAML or JSON files in the
# db/support_tables directory. The name of the file should be set as the underscored name
# of the class.
#
# You can use the `define_singlegtons_from` and `define_predicates_from`to define
# helper methods to load and test records. This can really help clean up the application
# logic because, for example, on a class `Color` you can call `Color.dark_gray` to the get
# record with name 'Dark Gray' and `color.dark_gray?` to test if the name is `Dark Gray`.
module SupportTableData

  extend ActiveSupport::Concern

  class_methods do
    # Synchronize the rows in the table with the values defined in the db/support_tables/table_name.yml
    # file. Note that rows will not be deleted if they are no longer in the data files. This method
    # should normally be called from a data migration. You should create a new migration any time
    # values in the data files are changed.
    # @return [void]
    def sync_table_data!
      key_attribute = (support_table_key_attribute || :id).to_s
      support_table_data.each do |attributes|
        key = attributes[key_attribute]
        record = find_or_initialize_by(key_attribute => key)
        attributes.each do |name, val|
          record.send("#{name}=", val) if record.respond_to?("#{name}=")
        end
        record.save! if record.changed?
      end
    end

    # Generate predicate methods based on the specified attribute name. A method will be defined
    # for each record in the support table data. The method name will be based on the attribute
    # value (i.e. "In Progress" would define the method `in_progress?`) and will return true
    # if the attribute is equal to the value. This allow us to make checks like `color.dark_gray?`
    # rather than `color.name == 'Dark Gray'`.
    # @param attribute_name [String, Symbol] The name of the attribute to use to define the methods.
    # @return [void]
    def define_predicates_from(attribute_name)
      attribute_name = attribute_name.to_s
      defined_methods = methods.map(&:to_s).to_set
      support_table_data.each do |attributes|
        value = attributes[attribute_name]&.to_s
        next if value.blank?

        method_name = "#{support_table_value_method_name(value)}?"
        next if defined_methods.include?(method_name)

        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{method_name}
            #{attribute_name} == #{value.inspect}
          end
        RUBY
      end
    end

    # Generate singleton methods based on the specified attribute name. A method will be defined
    # for each record in the support table data. The method name will be based on the attribute
    # value (i.e. "In Progress" would define the class method `in_progress`) and will return the
    # with the attribute equal to the value. This allow us to get records like `Color.dark_gray`
    # rather than `Color.find_by(name: 'Dark Gray')`.
    # @param attribute_name [String, Symbol] The name of the attribute to use to define the methods.
    # @return [void]
    def define_instances_from(attribute_name)
      attribute_name = attribute_name.to_s
      defined_methods = methods.map(&:to_s).to_set
      support_table_data.each do |attributes|
        value = attributes[attribute_name]&.to_s
        next if value.blank?

        method_name = support_table_value_method_name(value)
        next if defined_methods.include?(method_name)

        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def self.#{method_name}
            find_by(#{attribute_name.inspect} => #{value.inspect})
          end
        RUBY
      end
    end

    protected

    # Add a data file to load support table data from. This method can be called multiple times to
    # load data from multiple files.
    # @param data_file_path [String, Pathname] Path to a YAML or JSON file containing data for this model. If
    #   the path is a relative path, then it will be resolved from the default director set either for
    #   this model or the global directory set with SupportTableData.directory.
    # @param key The column name used for the the key value for the hash in the data file.
    # @return [void]
    def add_support_table_data(data_file_path)
      @support_table_data_files ||= []
      root_dir = (support_table_directory || SupportTableData.directory || Dir.pwd)
      @support_table_data_files << File.join(root_dir, data_file_path)
    end

    # Load the canonical data for the support table from the data files.
    # @return [Array<Hash>] Array of attributes for each row.
    def support_table_data
      @support_table_data_files ||= []
      data = {}
      key_attribute = (support_table_key_attribute || :id).to_s
      @support_table_data_files.each do |data_file_path|
        file_data = File.read(data_file_path)
        parsed_data = (data_file_path.downcase.end_with?(".json") ? JSON.parse(file_data) : YAML.safe_load(file_data))
        parsed_data.each do |key_value, attributes|
          key_value = key_value.to_s
          attributes = attributes.merge(key_attribute => key_value)
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

    private

    def support_table_value_method_name(value)
      method_name = value.to_s.downcase.gsub(/[^a-z0-9_]+/, '_')
      method_name = "_#{method_name}" unless method_name.match(/\A[a-z_]/)
      method_name
    end
  end

  included do
    protected

    # Define the unique key attribute used as the key in the hash defined in the data files.
    # This should be a value that never changes. By default it will be the id.
    class_attribute :support_table_key_attribute, instance_accessor: false

    # Define the directory where data files should be loaded from. This value will override the global
    # value set by SupportTableData.directory.
    class_attribute :support_table_directory, instance_accessor: false
  end

  class << self
    # Specify the directory where data files live by default.
    attr_writer :directory

    # Get the directory where data files live by default. If you are running in a Rails environment,
    # then this will be `db/support_tables`. Otherwise the current working directory will be used.
    # @return [String]
    def directory
      if defined?(@directory) && @directory
        @directory
      elsif defined?(Rails.root)
        File.join(Rails.root&.to_s, "db", "support_tables")
      else
        nil
      end
    end
  end
end

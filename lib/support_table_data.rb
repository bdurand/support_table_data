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
    end

    # Generate predicate methods based on the specified attribute name. A method will be defined
    # for each record in the support table data. The method name will be based on underscored
    # versions of the attribute value (i.e. "Dark Gray" would define the method `dark_gray?`).
    # The generated methods will return true if the attribute is equal to the value.
    #
    # @param attribute_name [String, Symbol] The name of the attribute to use to define the methods.
    # @param only [Array<Symbol, String>, Symbol, String] List of the only methods to create.
    # @param except [Array<Symbol, String>, Symbol, String] List of the methods not to create.
    # @return [void]
    def define_predicates_from(attribute_name, only: nil, except: nil)
      support_table_define_methods(attribute_name, only, except, true, instance_methods + private_instance_methods) do |method_name, value|
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{method_name}
            #{attribute_name} == #{value.inspect}
          end
        RUBY
      end
    end

    # Generate singleton methods based on the specified attribute name. A method will be defined
    # for each record in the support table data. The method name will be based on underscored
    # versions of the the attribute value (i.e. "Dark Gray" would define the class method `dark_gray`)
    # and will return the record with the attribute equal to the value.
    #
    # @param attribute_name [String, Symbol] The name of the attribute to use to define the methods.
    # @param only [Array<Symbol, String>, Symbol, String] List of the only methods to create.
    # @param except [Array<Symbol, String>, Symbol, String] List of the methods not to create.
    # @return [void]
    def define_instances_from(attribute_name, only: nil, except: nil)
      support_table_define_methods(attribute_name, only, except, false, methods + private_methods) do |method_name, value|
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def self.#{method_name}
            find_by!(#{attribute_name}: #{value.inspect})
          end
        RUBY
      end
    end

    # Helper method to define both instance and predicate methods from the same attribute and with
    # the same only or except filters.
    #
    # @param attribute_name [String, Symbol] The name of the attribute to use to define the methods.
    # @param only [Array<Symbol, String>, Symbol, String] List of the only methods to create.
    # @param except [Array<Symbol, String>, Symbol, String] List of the methods not to create.
    # @return [void]
    def define_instances_and_predicates_from(attribute_name, only: nil, except: nil)
      define_instances_from(attribute_name, only: only, except: except)
      define_predicates_from(attribute_name, only: only, except: except)
    end

    # Load the data for the support table from the data files.
    #
    # @return [Array<Hash>] Merged array of all the support table data.
    def support_table_data
      @support_table_data_files ||= []
      data = {}
      key_attribute = (support_table_key_attribute || :id).to_s

      @support_table_data_files.each do |data_file_path|
        support_table_parse_data_file(data_file_path).each do |attributes|
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

    # Iterate values to define helper methods.
    def support_table_define_methods(attribute_name, only, except, predicate, methods)
      attribute_name = attribute_name.to_s
      only = Array(only).collect(&:to_s) if only
      except = Array(except).collect(&:to_s) if except
      defined_methods = methods.collect(&:to_s).to_set

      support_table_data.each do |attributes|
        value = attributes[attribute_name]&.to_s
        next if value.blank?

        method_name = value.to_s.downcase.gsub(/[^a-z0-9_]+/, "_")
        method_name = "_#{method_name}" unless /\A[a-z_]/.match?(method_name)
        method_name = "#{method_name}?" if predicate
        next if defined_methods.include?(method_name)

        next if except && (except.include?(method_name) || except.include?(value))
        next if only && !only.include?(method_name) && !only.include?(value)

        yield method_name, value
      end
    end

    def support_table_parse_data_file(file_path)
      file_data = File.read(file_path)

      extension = file_path.split(".").last&.downcase
      case extension
      when "json"
        require "json" unless defined?(JSON)
        JSON.parse(file_data)
      when "csv"
        require "csv" unless defined?(CSV)
        data = []
        CSV.new(file_data, headers: true) do |row|
          data << row.to_h
        end
      else
        require "yaml" unless defined?(YAML)
        YAML.safe_load(file_data)
      end
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

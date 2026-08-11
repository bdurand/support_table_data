# frozen_string_literal: true

require "active_support/core_ext/module/redefine_method"
require "concurrent/map"

# This concern can be mixed into models that represent static support tables. These are small tables
# that have a limited number of rows, and have values that are often tied to the logic in the code.
#
# The values that should be in support tables can be defined in YAML, JSON, or CSV files. These
# values can then be synced to the database and helper methods can be generated from them.
module SupportTableData
  extend ActiveSupport::Concern

  autoload :ValidationError, File.expand_path("support_table_data/validation_error", __dir__)
  autoload :Documentation, File.expand_path("support_table_data/documentation", __dir__)
  autoload :Tasks, File.expand_path("support_table_data/tasks", __dir__)

  YARD_DOC_OPTIONS = [:full, :compact, :none].freeze

  @data_directory = nil
  @rbs_signatures_path = nil

  included do
    # Internal variables used for memoization.
    @support_table_mutex = Mutex.new
    @support_table_data_files = []
    @support_table_attribute_helpers = {}
    @support_table_instance_names = {}
    @support_table_instance_keys = nil
    @support_table_dependencies = []

    # Private class attribute to hold the key attribute name. Use `support_table_key_attribute` instead.
    # @private
    class_attribute :_support_table_key_attribute, instance_accessor: false
    class << self
      private :_support_table_key_attribute=
      private :_support_table_key_attribute
    end

    # Define the directory where data files should be loaded from. This value will override the global
    # value set by SupportTableData.data_directory. This is only used if relative paths are passed
    # in to add_support_table_data.
    class_attribute :support_table_data_directory, instance_accessor: false

    # Private class attribute backing `support_table_yard_docs`. Use the public
    # accessor to read/write.
    # @private
    class_attribute :_support_table_yard_docs, instance_accessor: false, default: :full
    class << self
      private :_support_table_yard_docs=
      private :_support_table_yard_docs
    end
  end

  class_methods do
    # Define the attribute used as the key of the hash in the data files.
    # This should be an attribute with values that never change.
    # By default the key attribute will be the table's primary key.
    def support_table_key_attribute=(attribute_name)
      self._support_table_key_attribute = attribute_name&.to_s
    end

    # Get the attribute used as the unique to identify records in the data files.
    #
    # @return [String] The name of the key attribute.
    def support_table_key_attribute
      _support_table_key_attribute || "id"
    end

    # Get the YARD documentation mode for this model. One of:
    #
    # * `:full`    - emit a verbose comment block per generated method (default)
    # * `:compact` - emit shared @!macro definitions plus a short comment
    #                block per generated method that expands them
    # * `:none`    - generate no YARD docs for this model; the rake task will
    #                strip any existing generated YARD docs
    #
    # @return [Symbol]
    def support_table_yard_docs
      _support_table_yard_docs
    end

    # Set the YARD documentation mode for this model. See `support_table_yard_docs`
    # for the supported values.
    #
    # @param value [Symbol]
    # @return [void]
    def support_table_yard_docs=(value)
      unless SupportTableData::YARD_DOC_OPTIONS.include?(value)
        raise ArgumentError, "support_table_yard_docs must be one of #{SupportTableData::YARD_DOC_OPTIONS.inspect} (got #{value.inspect})"
      end
      self._support_table_yard_docs = value
    end

    # Synchronize the rows in the table with the values defined in the data files added with
    # `add_support_table_data`. By default, rows that are no longer present in the data files
    # will not be deleted unless `delete_missing` is enabled.
    #
    # @param delete_missing [Boolean] If true, then any records in the database that are not in the data
    #   files will be deleted. Use with caution.
    # @return [Array<Hash>] List of saved changes for each record that was created or modified.
    def sync_table_data!(delete_missing: false)
      return [] unless table_exists?

      retried = false

      # The instrumentation wraps the retry so that one call emits one event even if the
      # sync has to be attempted twice.
      ActiveSupport::Notifications.instrument("support_table_data.sync", class: self) do
        canonical_data = support_table_data.each_with_object({}) do |attributes, hash|
          hash[attributes[support_table_key_attribute].to_s] = attributes
        end

        if canonical_data.include?("")
          raise ArgumentError.new("Cannot sync #{name} because the data files contain a row with no value for the key attribute #{support_table_key_attribute}")
        end

        if delete_missing && canonical_data.empty? && exists?
          raise ArgumentError.new("Refusing to sync #{name} with delete_missing enabled because the data files contain no rows; this would delete every row in the table")
        end

        # Rows are matched on the key attribute alone, so the lookup must not be scoped
        # to this class's single table inheritance type. A subclass syncing rows from
        # inherited data files has to find them no matter what type they currently have
        # or it would insert duplicates.
        scope = finder_needs_type_condition? ? base_class : self
        records = scope.where(support_table_key_attribute => canonical_data.keys)

        # New rows default to the type of the class whose data files define them so that
        # a subclass syncing inherited files does not create them with its own type.
        record_classes = support_table_record_classes

        changes = []
        synced_ids = []

        transaction do
          records.each do |record|
            key = record[support_table_key_attribute].to_s
            attributes = canonical_data.delete(key)
            attributes&.each do |name, value|
              record.send(:"#{name}=", value) if record.respond_to?(:"#{name}=", true)
            end
            if support_table_record_changed?(record)
              changes << record.changes
              record.save!
            end

            synced_ids << record.id if attributes
          end

          canonical_data.each_value do |attributes|
            class_name = attributes[inheritance_column]
            klass = if class_name
              sti_class_for(class_name)
            else
              record_classes[attributes[support_table_key_attribute].to_s] || self
            end
            record = klass.new
            attributes.each do |name, value|
              record.send(:"#{name}=", value) if record.respond_to?(:"#{name}=", true)
            end
            changes << record.changes
            record.save!
            synced_ids << record.id
          end

          delete_missing_records(where.not(primary_key => synced_ids)) if delete_missing
        end

        changes
      rescue ActiveRecord::RecordInvalid => e
        raise SupportTableData::ValidationError.new(e.record)
      rescue ActiveRecord::RecordNotUnique
        # A concurrent sync from another process may have inserted the same rows.
        # The transaction was rolled back, so retry once to pick up those rows.
        raise if retried

        retried = true
        retry
      end
    end

    # Add a data file that contains the support table data. This method can be called multiple times to
    # load data from multiple files.
    #
    # @param data_file_path [String, Pathname] The path to a YAML, JSON, or CSV file containing data for this model. If
    #   the path is a relative path, then it will be resolved from the either the default directory set for
    #   this model or the global directory set with SupportTableData.data_directory.
    # @return [void]
    def add_support_table_data(data_file_path)
      root_dir = support_table_data_directory || SupportTableData.data_directory || Dir.pwd
      support_table_mutex.synchronize do
        # Only the files added directly to this class are stored on it. Files added to a
        # base class are composed in at read time so a single table inheritance subclass
        # sees files the base class adds later, no matter the order the classes set up in.
        @support_table_data_files = (@support_table_data_files || []) + [File.expand_path(data_file_path, root_dir)]
      end
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
      support_table_mutex.synchronize do
        # Single table inheritance subclasses read the map from their base class. Copy it
        # (including the lists of method names that have been defined) the first time a
        # subclass registers its own helpers so the two classes don't mutate each other's state.
        @support_table_attribute_helpers ||= support_table_attribute_helpers_map.transform_values(&:dup)

        attributes.flatten.collect(&:to_s).each do |attribute|
          next if @support_table_attribute_helpers.include?(attribute)

          @support_table_attribute_helpers = @support_table_attribute_helpers.merge(attribute => [])
        end
      end
      define_support_table_named_instances
    end

    # Get the names of any named instance attribute helpers that have been defined
    # with `named_instance_attribute_helpers`.
    #
    # @return [Array<String>] List of attribute names.
    def support_table_attribute_helpers
      support_table_attribute_helpers_map.keys
    end

    # Get the data for the support table from the data files.
    #
    # @return [Array<Hash>] List of attributes for all records in the data files.
    def support_table_data
      support_table_data_for_files(support_table_data_files)
    end

    # Get the data for the support table from a specific list of data files.
    #
    # @param data_files [Array<String>] The paths of the data files to read.
    # @return [Array<Hash>] List of attributes for all records in the data files.
    # @api private
    def support_table_data_for_files(data_files)
      support_table_merged_records(data_files).first
    end

    # Get the data for a named instances from the data files.
    #
    # @return [Hasn] Hash of named instance attributes.
    def named_instance_data(name)
      support_table_merged_records(support_table_data_files).last[name.to_s] || {}
    end

    # Get the names of all named instances.
    #
    # @return [Array<String>] List of all instance names.
    def instance_names
      support_table_instance_names_map.keys
    end

    # Load a named instance from the database.
    #
    # @param instance_name [String, Symbol] The name of the instance to load as defined in the data files.
    # @return [ActiveRecord::Base] The instance loaded from the database.
    # @raise [ActiveRecord::RecordNotFound] If the instance does not exist.
    def named_instance(instance_name)
      instance_name = instance_name.to_s
      instances = support_table_instance_names_map
      unless instances.include?(instance_name)
        raise ActiveRecord::RecordNotFound.new("Couldn't find #{name} named instance #{instance_name.inspect}")
      end

      find_by!(support_table_key_attribute => instances[instance_name])
    end

    # Get the key values for all instances loaded from the data files. Data files added to
    # single table inheritance subclasses are included since those rows live in this table too.
    #
    # @return [Array] List of all the key attribute values.
    def instance_keys
      support_table_cached_data_value(:@support_table_instance_keys, support_table_data_files_with_descendants) do |data_files|
        values = []
        support_table_data_for_files(data_files).each do |attributes|
          key_value = attributes[support_table_key_attribute]
          instance = new
          instance.send(:"#{support_table_key_attribute}=", key_value)
          values << instance.send(support_table_key_attribute)
        end
        values.uniq
      end
    end

    # Return true if the instance has data being managed from a data file. Instances are matched
    # on the key attribute only. Single table inheritance types are intentionally not considered
    # when matching since syncing also matches existing rows on just the key attribute and will
    # overwrite a row regardless of the type it currently has. Data files added to single table
    # inheritance subclasses are included since those rows live in this table too.
    #
    # @return [Boolean]
    def protected_instance?(instance)
      key = instance[support_table_key_attribute].to_s
      return true if support_table_protected_keys.include?(key)

      # The instance may be a single table inheritance subclass that had not been loaded yet
      # when the keys for this class were calculated. Loading a row instantiates it as its own
      # subclass, so the subclass can be asked directly rather than relying on it having been
      # eager loaded before this point.
      instance_class = instance.class
      return false if instance_class == self || !instance_class.include?(SupportTableData)

      instance_class.send(:support_table_protected_keys).include?(key)
    end

    # Explicitly define other support tables that this model depends on. A support table depends
    # on another support table it needs to reference data on that table when loading its own data.
    # Normally this is handled automatically by looking at the belongs_to associations on the model.
    # In some cases, though, you may need to explicitly define the relationship. For instance, if
    # there's a join table between two associations with the data poplulated from one support table's
    # data file by referencing values maintained by the other support table. In this case,
    # you need to define the dependency so that the tables are loaded in the correct order.
    #
    # @param class_names [String] List of class names that this support table depends on.
    # @return [void]
    def support_table_dependency(*class_names)
      support_table_mutex.synchronize do
        @support_table_dependencies = support_table_dependency_names + class_names.flatten.collect(&:to_s)
      end
    end

    private

    # Destroy the rows in a relation that are not managed from a data file.
    #
    # Rows managed by data files added to single table inheritance subclasses live in this
    # table, but they are synced by the subclass, so they must not be deleted here. Loading a
    # row instantiates it as its own subclass, which loads that class if it hasn't been loaded
    # yet, so `protected_instance?` can consult the subclass directly without having to eager
    # load the entire application first.
    #
    # @param relation [ActiveRecord::Relation] The rows that are candidates for deletion.
    # @return [void]
    def delete_missing_records(relation)
      relation.find_each do |record|
        next if protected_instance?(record)

        record.destroy
      end
    end

    # The key attribute values of every row managed from this class' data files, including
    # data files added to single table inheritance subclasses that have already been loaded.
    #
    # @return [Array<String>]
    def support_table_protected_keys
      support_table_cached_data_value(:@support_table_protected_keys, support_table_data_files_with_descendants) do |data_files|
        support_table_data_for_files(data_files).collect { |attributes| attributes[support_table_key_attribute].to_s }
      end
    end

    # Parse the data files and merge the records they define. Files are processed in
    # order so that later files take precedence no matter how each file is structured.
    # Records are matched both by their instance name and by their key attribute value.
    # Entry names that begin with an underscore do not define named instances; their
    # values hold anonymous records identified only by the key attribute.
    #
    # @param data_files [Array<String>] The paths of the data files to read.
    # @return [Array(Array<Hash>, Hash<String, Hash>)] The ordered list of merged records
    #   and the named instance records by name.
    def support_table_merged_records(data_files)
      records = []
      named_records = {}
      keyed_records = {}

      merge_record = lambda do |attributes, instance_name|
        record = named_records[instance_name] if instance_name
        if record.nil? && (instance_name.nil? || attributes.include?(support_table_key_attribute))
          record = keyed_records[attributes[support_table_key_attribute].to_s]
        end

        if record
          record.merge!(attributes)
        else
          record = attributes.dup
          records << record
        end

        named_records[instance_name] = record if instance_name
        keyed_records[record[support_table_key_attribute].to_s] = record
      end

      data_files.each do |data_file_path|
        file_data = support_table_parse_data_file(data_file_path)

        unless file_data.is_a?(Hash)
          Array(file_data).flatten.each { |attributes| merge_record.call(attributes, nil) }
          next
        end

        file_data.each do |instance_name, attributes|
          instance_name = instance_name.to_s
          if instance_name.start_with?("_")
            anonymous_records = attributes.is_a?(Hash) ? [attributes] : Array(attributes).flatten
            anonymous_records.each { |record_attributes| merge_record.call(record_attributes, nil) }
          elsif attributes.is_a?(Hash)
            merge_record.call(attributes, instance_name)
          else
            raise ArgumentError.new("Cannot define named instance #{instance_name} on #{name}; value must be a Hash")
          end
        end
      end

      [records, named_records]
    end

    # The classes in the hierarchy that added their own data files, listed base class
    # first, along with the file paths each one added.
    #
    # @return [Array<Array(Class, Array<String>)>]
    def support_table_data_file_owners
      owners = superclass.include?(SupportTableData) ? superclass.send(:support_table_data_file_owners) : []
      own_files = @support_table_data_files
      owners += [[self, own_files]] if own_files && !own_files.empty?
      owners
    end

    # Map each record's key attribute value to the class in the hierarchy whose own data
    # files define it. Used to determine the single table inheritance type for new rows
    # that do not specify one in the data files.
    #
    # @return [Hash<String, Class>]
    def support_table_record_classes
      record_classes = {}
      support_table_data_file_owners.each do |owner, files|
        next if owner == self

        support_table_data_for_files(files).each do |attributes|
          record_classes[attributes[support_table_key_attribute].to_s] ||= owner
        end
      end
      record_classes
    end

    def define_support_table_named_instances
      support_table_merged_records(support_table_data_files).last.each do |name, attributes|
        support_table_mutex.synchronize do
          define_support_table_named_instance_methods(name, attributes)
        end
      end
    end

    def define_support_table_named_instance_methods(name, attributes)
      method_name = name.to_s.freeze
      return if method_name.start_with?("_")

      unless attributes.is_a?(Hash)
        raise ArgumentError.new("Cannot define named instance #{method_name} on #{self.name}; value must be a Hash")
      end

      unless method_name.match?(/\A[a-z][a-z0-9_]+\z/)
        raise ArgumentError.new("Cannot define named instance #{method_name} on #{self.name}; name contains illegal characters")
      end

      key_value = attributes[support_table_key_attribute]
      instance_names_map = support_table_instance_names_map

      if instance_names_map.include?(method_name)
        if instance_names_map[method_name] != key_value
          define_support_table_instance_helper(method_name, support_table_key_attribute, key_value, redefine: true)
          define_support_table_predicates_helper("#{method_name}?", support_table_key_attribute, key_value, redefine: true)
          @support_table_instance_names = (@support_table_instance_names || {}).merge(method_name => key_value)
        end
      else
        define_support_table_instance_helper(method_name, support_table_key_attribute, key_value)
        define_support_table_predicates_helper("#{method_name}?", support_table_key_attribute, key_value)
        @support_table_instance_names = (@support_table_instance_names || {}).merge(method_name => key_value)
      end

      support_table_attribute_helpers_map.each do |attribute_name, defined_methods|
        attribute_method_name = "#{method_name}_#{attribute_name}"
        if defined_methods.include?(attribute_method_name)
          define_support_table_instance_attribute_helper(attribute_method_name, attributes[attribute_name], redefine: true)
        else
          define_support_table_instance_attribute_helper(attribute_method_name, attributes[attribute_name])
          defined_methods << attribute_method_name
        end
      end
    end

    # Values from the data files are captured in the method closures rather than being
    # interpolated into the method body as literals. Not every value that can appear in a
    # data file has an `inspect` representation that is valid Ruby source (`Date` and `Time`
    # are the notable ones), so interpolating them would raise a SyntaxError when the method
    # is defined.
    def define_support_table_instance_helper(method_name, attribute_name, attribute_value, redefine: false)
      if redefine
        singleton_class.silence_redefinition_of_method(method_name)
      elsif respond_to?(method_name, true)
        raise ArgumentError.new("Could not define support table helper method #{name}.#{method_name} because it is already a defined method")
      end

      attribute_name = attribute_name.to_s
      singleton_class.send(:define_method, method_name) do
        find_by!(attribute_name => attribute_value)
      end
    end

    def define_support_table_instance_attribute_helper(method_name, attribute_value, redefine: false)
      if redefine
        singleton_class.silence_redefinition_of_method(method_name)
      elsif respond_to?(method_name, true)
        raise ArgumentError.new("Could not define support table helper method #{name}.#{method_name} because it is already a defined method")
      end

      # The value is returned directly on every call, so it is copied and frozen to keep
      # callers from mutating the data shared by all of them.
      value = support_table_deep_freeze(attribute_value.dup)
      singleton_class.send(:define_method, method_name) { value }
    end

    def define_support_table_predicates_helper(method_name, attribute_name, attribute_value, redefine: false)
      if redefine
        silence_redefinition_of_method(method_name)
      elsif method_defined?(method_name) || private_method_defined?(method_name)
        raise ArgumentError.new("Could not define support table helper method #{name}##{method_name} because it is already a defined method")
      end

      attribute_name = attribute_name.to_s
      # The value has to be cast to the attribute type before it can be compared to the value
      # read off the record. The cast is done lazily and memoized per class because the type
      # requires a database connection to resolve, which is not necessarily available when the
      # model class is being loaded. The map is shared by every instance, so it needs to be
      # thread safe on Ruby implementations without a global interpreter lock.
      cast_values = Concurrent::Map.new
      define_method(method_name) do
        klass = self.class
        cast_value = cast_values.fetch_or_store(klass) do
          klass.type_for_attribute(attribute_name).cast(attribute_value)
        end
        send(attribute_name) == cast_value
      end
    end

    def support_table_deep_freeze(value)
      case value
      when Hash
        value.each_value { |element| support_table_deep_freeze(element) }
      when Array
        value.each { |element| support_table_deep_freeze(element) }
      end
      value.freeze
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
        require "date" unless defined?(Date)
        data = YAML.safe_load(file_data, permitted_classes: [Date, Time], aliases: true)
      end

      data
    end

    def support_table_record_changed?(record, seen = Set.new)
      return true if record.changed?

      seen << record
      record.class.reflect_on_all_associations.detect do |reflection|
        next false if reflection.belongs_to?
        next false unless reflection.options[:autosave]

        record.association(reflection.name).target.any? do |child|
          support_table_record_changed?(child, seen) unless seen.include?(child)
        end
      end
    end

    # Memoize a value calculated from the data files in an instance variable on this class.
    # The list of data files used to calculate the value is cached along with it so that the
    # value is recalculated whenever the list changes. This keeps the value from going stale
    # when a data file is added after it was first calculated, including when the file is added
    # to a base class after a single table inheritance subclass has cached its own copy or when
    # a subclass that adds its own data files is loaded lazily.
    #
    # @param variable_name [Symbol] The name of the instance variable to memoize the value in.
    # @param data_files [Array<String>] The data files the value is calculated from. These are
    #   yielded to the block and cached with the value so it can be invalidated.
    # @return [Object] The cached value.
    def support_table_cached_data_value(variable_name, data_files)
      cached = instance_variable_get(variable_name)
      return cached.last if cached && cached.first == data_files

      support_table_mutex.synchronize do
        cached = instance_variable_get(variable_name)
        unless cached && cached.first == data_files
          cached = [data_files.dup.freeze, yield(data_files)].freeze
          instance_variable_set(variable_name, cached)
        end
      end

      cached.last
    end

    # Get the list of data files for this class along with any added to single table inheritance
    # subclasses. Rows from a subclass' data files live in the same table, so they need to be
    # included when determining which rows in the table are managed from data files.
    #
    # Note that this can only detect subclasses that have already been loaded by the application.
    #
    # @return [Array<String>] List of data file paths.
    def support_table_data_files_with_descendants
      files = support_table_data_files

      descendants.each do |subclass|
        next unless subclass.include?(SupportTableData)

        files |= subclass.send(:support_table_data_files)
      end

      files
    end

    # The class level state used by the concern is stored in instance variables on the
    # class where the concern was included. These readers compose in or fall back to the
    # superclass state so that single table inheritance subclasses share the state defined
    # on their base class rather than crashing on uninitialized instance variables.

    def support_table_mutex
      @support_table_mutex || (superclass.include?(SupportTableData) ? superclass.send(:support_table_mutex) : nil)
    end

    def support_table_data_files
      inherited = superclass.include?(SupportTableData) ? superclass.send(:support_table_data_files) : []
      own = @support_table_data_files || []
      inherited.empty? ? own : inherited + own
    end

    def support_table_instance_names_map
      inherited = superclass.include?(SupportTableData) ? superclass.send(:support_table_instance_names_map) : {}
      own = @support_table_instance_names || {}
      inherited.empty? ? own : inherited.merge(own)
    end

    def support_table_attribute_helpers_map
      @support_table_attribute_helpers || (superclass.include?(SupportTableData) ? superclass.send(:support_table_attribute_helpers_map) : {})
    end

    def support_table_dependency_names
      @support_table_dependencies || (superclass.include?(SupportTableData) ? superclass.send(:support_table_dependency_names) : [])
    end
  end

  class << self
    # @attribute [r]
    #   The the default directory where data files live.
    #   @return [String, nil]
    attr_reader :data_directory

    # Set the default directory where data files live.
    #
    # @param value [String, Pathname, nil] The path to the directory.
    # @return [void]
    def data_directory=(value)
      @data_directory = value&.to_s
    end

    # Override the directory under which generated RBS signature files are
    # written. When nil (the default) signatures go to
    # `<project_root>/sig/<model_path>.rbs`, where the project root is the
    # nearest ancestor directory containing a Gemfile or .git directory.
    #
    # @return [String, Pathname, nil]
    attr_accessor :rbs_signatures_path

    # Sync all support table classes. Classes must already be loaded in order to be synced.
    #
    # You can pass in a list of classes that you want to ensure are synced. This feature
    # can be used to force load classes that are only loaded at runtime. For instance, if
    # eager loading is turned off for the test environment in a Rails application (which is
    # the default), then there is a good chance that support table models won't be loaded
    # when the test suite is initializing.
    #
    # @param extra_classes [Class] List of classes to force into the detected list of classes to sync.
    # @param delete_missing [Boolean] If true, then any records in the database that are not in the data
    #   files will be deleted from each table. Use with caution.
    # @return [Hash<Class, Array<Hash>] Hash of classes synced with a list of saved changes.
    def sync_all!(*extra_classes, delete_missing: false)
      changes = {}
      support_table_classes(*extra_classes).each do |klass|
        changes[klass] = klass.sync_table_data!(delete_missing: delete_missing)
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
        Dir.glob(File.join(SupportTableData.data_directory, "**", "*")).sort.each do |file_name|
          file_name = file_name.delete_prefix("#{SupportTableData.data_directory}#{File::SEPARATOR}")
          class_name = file_name.sub(/\.[^.]*\z/, "").singularize.camelize
          class_name.safe_constantize
        end
      end

      active_record_classes = ActiveRecord::Base.descendants.reject { |klass| klass.name.nil? }
      active_record_classes.sort_by(&:name).each do |klass|
        next unless klass.include?(SupportTableData)
        next unless klass.instance_variable_defined?(:@support_table_data_files) && klass.instance_variable_get(:@support_table_data_files).is_a?(Array)
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
      dependencies = klass.send(:support_table_dependency_names).collect(&:constantize)

      klass.reflections.values.each do |reflection|
        next if reflection.polymorphic?
        next unless reflection.klass.include?(SupportTableData)
        next if reflection.klass <= klass
        next unless reflection.belongs_to? || reflection.through_reflection?
        next if dependencies.include?(reflection.klass)

        explicit_dependencies = reflection.klass.send(:support_table_dependency_names)
        next if explicit_dependencies.include?(klass.name)

        dependencies << reflection.klass
      rescue => e
        message = "Error inspecting reflection #{reflection.name} on #{klass.name}: #{e.inspect}"
        klass.logger&.warn(message)
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

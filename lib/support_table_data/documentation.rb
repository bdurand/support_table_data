# frozen_string_literal: true

module SupportTableData
  class Documentation
    # Create a new documentation generator for a configuration class.
    #
    # @param config_class [Class] The configuration class to generate documentation for
    def initialize(klass)
      @klass = klass
    end

    # Generate YARD documentation class definition for the model's helper methods.
    #
    # @return [String, nil] The YARD documentation class definition, or nil if no named instances
    def class_def_with_yard_docs
      instance_names = klass.instance_names
      return nil if instance_names.empty?

      generate_yard_class(instance_names)
    end

    # Generate YARD documentation comment for named instance singleton method.
    #
    # @param name [String] The name of the instance method.
    # @return [String] The YARD comment text
    def instance_helper_yard_doc(name)
      <<~YARD
        # Find the #{name} record from the database.
        #
        # @return [#{klass.name}] the #{name} record
        # @raise [ActiveRecord::RecordNotFound] if the record does not exist
        # @!method self.#{name}
      YARD
    end

    # Generate YARD documentation comment for the predicate method for the named instance.
    #
    # @param name [String] The name of the instance method.
    # @return [String] The YARD comment text
    def predicate_helper_yard_doc(name)
      <<~YARD
        # Check if this record is the #{name} record.
        #
        # @return [Boolean] true if this is the #{name} record, false otherwise
        # @!method #{name}?
      YARD
    end

    # Generate YARD documentation comment for the attribute method helper for the named instance.
    #
    # @param name [String] The name of the instance method.
    # @return [String] The YARD comment text
    def attribute_helper_yard_doc(name, attribute_name)
      <<~YARD
        # Get the #{name} record's #{attribute_name}.
        #
        # @return [Object] the #{name} record's #{attribute_name}
        # @!method #{name}_#{attribute_name}
      YARD
    end

    private

    attr_reader :klass

    def generate_yard_class(instance_names)
      return nil if instance_names.empty?

      yard_lines = ["class #{klass.name}"]

      # Generate docs for each named instance
      instance_names.sort.each_with_index do |name, index|
        yard_lines << "" unless index.zero?
        instance_helper_yard_doc(name).each_line(chomp: true) { |line| yard_lines << "  #{line}" }
        yard_lines << ""
        predicate_helper_yard_doc(name).each_line(chomp: true) { |line| yard_lines << "  #{line}" }
        klass.support_table_attribute_helpers.each do |attribute_name|
          yard_lines << ""
          attribute_helper_yard_doc(name, attribute_name).each_line(chomp: true) { |line| yard_lines << "  #{line}" }
        end
      end

      yard_lines << "end"

      yard_lines.join("\n")
    end
  end
end

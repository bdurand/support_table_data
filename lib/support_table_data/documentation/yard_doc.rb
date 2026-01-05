# frozen_string_literal: true

module SupportTableData
  module Documentation
    class YardDoc
      # @param klass [Class] The model class to generate documentation for
      def initialize(klass)
        @klass = klass
      end

      # Generate YARD documentation class definition for the model's helper methods.
      #
      # @return [String, nil] The YARD documentation class definition, or nil if no named instances
      def named_instance_yard_docs
        instance_names = klass.instance_names
        generate_yard_docs(instance_names)
      end

      # Generate YARD documentation comment for named instance singleton method.
      #
      # @param name [String] The name of the instance method.
      # @return [String] The YARD comment text
      def instance_helper_yard_doc(name)
        <<~YARD.chomp("\n")
          # Find the named instance +#{name}+ from the database.
          #
          # @!method self.#{name}
          # @return [#{klass.name}]
          # @raise [ActiveRecord::RecordNotFound] if the record does not exist
          # @!visibility public
        YARD
      end

      # Generate YARD documentation comment for the predicate method for the named instance.
      #
      # @param name [String] The name of the instance method.
      # @return [String] The YARD comment text
      def predicate_helper_yard_doc(name)
        <<~YARD.chomp("\n")
          # Check if this record is the named instance +#{name}+.
          #
          # @!method #{name}?
          # @return [Boolean]
          # @!visibility public
        YARD
      end

      # Generate YARD documentation comment for the attribute method helper for the named instance.
      #
      # @param name [String] The name of the instance method.
      # @return [String] The YARD comment text
      def attribute_helper_yard_doc(name, attribute_name)
        <<~YARD.chomp("\n")
          # Get the #{attribute_name} attribute from the data file
          # for the named instance +#{name}+.
          #
          # @!method self.#{name}_#{attribute_name}
          # @return [Object]
          # @!visibility public
        YARD
      end

      private

      attr_reader :klass

      def generate_yard_docs(instance_names)
        return nil if instance_names.empty?

        yard_lines = ["# @!group Named Instances"]

        # Generate docs for each named instance
        instance_names.sort.each do |name|
          yard_lines << ""
          yard_lines << instance_helper_yard_doc(name)
          yard_lines << ""
          yard_lines << predicate_helper_yard_doc(name)
          klass.support_table_attribute_helpers.each do |attribute_name|
            yard_lines << ""
            yard_lines << attribute_helper_yard_doc(name, attribute_name)
          end
        end

        yard_lines << ""
        yard_lines << "# @!endgroup"

        yard_lines.join("\n")
      end
    end
  end
end

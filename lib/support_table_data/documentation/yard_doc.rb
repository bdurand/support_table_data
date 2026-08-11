# frozen_string_literal: true

module SupportTableData
  module Documentation
    class YardDoc
      # @param klass [Class] The model class to generate documentation for
      def initialize(klass)
        @klass = klass
      end

      # Generate YARD documentation for the model's helper methods. The format
      # is controlled by the model's `support_table_yard_docs` setting:
      #
      # * `:full`    - verbose comment block per method (default)
      # * `:compact` - the same tags per method without the prose descriptions
      # * `:none`    - generate no docs at all
      #
      # @return [String, nil] The YARD documentation, or nil if no docs should
      #   be emitted (either because the model has no named instances or because
      #   `support_table_yard_docs` is `:none`).
      def named_instance_yard_docs
        return nil if klass.support_table_yard_docs == :none

        instance_names = klass.instance_names
        return nil if instance_names.empty?

        case klass.support_table_yard_docs
        when :compact
          generate_compact_yard_docs(instance_names)
        else
          generate_verbose_yard_docs(instance_names)
        end
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
      # @param attribute_name [String] The attribute being read.
      # @return [String] The YARD comment text
      def attribute_helper_yard_doc(name, attribute_name)
        return_type = attribute_yard_return_type(name, attribute_name)
        <<~YARD.chomp("\n")
          # Get the #{attribute_name} attribute from the data file
          # for the named instance +#{name}+.
          #
          # @!method self.#{name}_#{attribute_name}
          # @return [#{return_type}]
          # @!visibility public
        YARD
      end

      private

      attr_reader :klass

      def generate_verbose_yard_docs(instance_names)
        yard_lines = ["# @!group Named Instances"]

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

      # The compact format drops the prose description from each method and keeps only the
      # tags. Every method still needs its own comment block separated by a blank line:
      # YARD builds one docstring per block, so combining methods into a single block would
      # both drop the tags for all but the last method and leak the `self.` scope of a
      # singleton method onto the instance methods that follow it.
      def generate_compact_yard_docs(instance_names)
        yard_lines = ["# @!group Named Instances"]

        instance_names.sort.each do |name|
          yard_lines << ""
          yard_lines << compact_instance_helper_yard_doc(name)
          yard_lines << ""
          yard_lines << compact_predicate_helper_yard_doc(name)
          klass.support_table_attribute_helpers.each do |attribute_name|
            yard_lines << ""
            yard_lines << compact_attribute_helper_yard_doc(name, attribute_name)
          end
        end

        yard_lines << ""
        yard_lines << "# @!endgroup"

        yard_lines.join("\n")
      end

      def compact_instance_helper_yard_doc(name)
        <<~YARD.chomp("\n")
          # @!method self.#{name}
          # @return [#{klass.name}]
          # @raise [ActiveRecord::RecordNotFound] if the record does not exist
          # @!visibility public
        YARD
      end

      def compact_predicate_helper_yard_doc(name)
        <<~YARD.chomp("\n")
          # @!method #{name}?
          # @return [Boolean]
          # @!visibility public
        YARD
      end

      def compact_attribute_helper_yard_doc(name, attribute_name)
        <<~YARD.chomp("\n")
          # @!method self.#{name}_#{attribute_name}
          # @return [#{attribute_yard_return_type(name, attribute_name)}]
          # @!visibility public
        YARD
      end

      def attribute_yard_return_type(name, attribute_name)
        TypeInference.yard_type(TypeInference.value_type(klass, name, attribute_name))
      end
    end
  end
end

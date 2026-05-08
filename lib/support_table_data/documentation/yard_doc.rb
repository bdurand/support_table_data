# frozen_string_literal: true

module SupportTableData
  module Documentation
    class YardDoc
      MACRO_FINDER = "support_table_data_finder"
      MACRO_PREDICATE = "support_table_data_predicate"
      MACRO_ATTRIBUTE = "support_table_data_attribute"

      # @param klass [Class] The model class to generate documentation for
      def initialize(klass)
        @klass = klass
      end

      # Generate YARD documentation for the model's helper methods. The format
      # is controlled by the model's `support_table_yard_docs` setting:
      #
      # * `:full`    - verbose comment block per method (default)
      # * `:compact` - shared @!macro definitions plus a short @!method/@!macro
      #                pair per generated method
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
        return_type = TypeInference.yard_type(TypeInference.column_type(klass, attribute_name))
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

      def generate_compact_yard_docs(instance_names)
        yard_lines = ["# @!group Named Instances"]
        yard_lines << ""
        yard_lines << compact_preamble
        yard_lines << ""
        yard_lines << compact_macro_definitions

        instance_names.sort.each do |name|
          yard_lines << ""
          yard_lines << compact_instance_block(name)
        end

        yard_lines << ""
        yard_lines << "# @!endgroup"

        yard_lines.join("\n")
      end

      def compact_preamble
        <<~YARD.chomp("\n")
          # The methods in this group are dynamically defined by support_table_data
          # for each named instance in the data file. The macros below are the
          # documentation templates; the per-instance @!method lines that follow
          # invoke them with the instance name (and attribute name, where applicable).
        YARD
      end

      def compact_macro_definitions
        attribute_macro = <<~YARD.chomp("\n")
          # @!macro [new] #{MACRO_ATTRIBUTE}
          #   Get the +$2+ attribute from the data file for the named instance +$1+.
          #   @return [$3]
          #   @!visibility public
        YARD

        finder_macro = <<~YARD.chomp("\n")
          # @!macro [new] #{MACRO_FINDER}
          #   Find the named instance +$1+ from the database.
          #   @return [#{klass.name}]
          #   @raise [ActiveRecord::RecordNotFound] if the record does not exist
          #   @!visibility public
        YARD

        predicate_macro = <<~YARD.chomp("\n")
          # @!macro [new] #{MACRO_PREDICATE}
          #   Check if this record is the named instance +$1+.
          #   @return [Boolean]
          #   @!visibility public
        YARD

        [finder_macro, "", predicate_macro, "", attribute_macro].join("\n")
      end

      def compact_instance_block(name)
        lines = []
        lines << "# @!method self.#{name}"
        lines << "# @!macro #{MACRO_FINDER} #{name}"
        lines << "# @!method #{name}?"
        lines << "# @!macro #{MACRO_PREDICATE} #{name}"
        klass.support_table_attribute_helpers.each do |attribute_name|
          return_type = TypeInference.yard_type(TypeInference.column_type(klass, attribute_name))
          lines << "# @!method self.#{name}_#{attribute_name}"
          lines << "# @!macro #{MACRO_ATTRIBUTE} #{name} #{attribute_name} #{return_type}"
        end
        lines.join("\n")
      end
    end
  end
end

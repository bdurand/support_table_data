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
      # * `:compact` - shared @!macro definitions plus a short comment block
      #                per method that expands them
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

      # The compact format defines the shared documentation once as macros and expands
      # them under each generated method. YARD imposes three rules on this layout: each
      # method needs its own comment block (tags and the `self.` scope apply to the whole
      # block), a macro invocation must be indented under its @!method line to attach to
      # that method, and macro parameters ($1, etc.) cannot be used because YARD only
      # fills them in from real method calls in the source. Macro names are global to the
      # YARD registry, so they are namespaced with the class name.
      def generate_compact_yard_docs(instance_names)
        yard_lines = ["# @!group Named Instances"]
        yard_lines << ""
        yard_lines << compact_macro_definitions

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

      def compact_macro_definitions
        finder_macro = <<~YARD.chomp("\n")
          # @!macro [new] #{compact_macro_name("finder")}
          #   Find this named instance from the database.
          #   @return [#{klass.name}]
          #   @raise [ActiveRecord::RecordNotFound] if the record does not exist
          #   @!visibility public
        YARD

        predicate_macro = <<~YARD.chomp("\n")
          # @!macro [new] #{compact_macro_name("predicate")}
          #   Check if this record is this named instance.
          #   @return [Boolean]
          #   @!visibility public
        YARD

        macros = [finder_macro, "", predicate_macro]

        if klass.support_table_attribute_helpers.any?
          attribute_macro = <<~YARD.chomp("\n")
            # @!macro [new] #{compact_macro_name("attribute")}
            #   Get this attribute from the data file for this named instance.
            #   @!visibility public
          YARD
          macros << ""
          macros << attribute_macro
        end

        macros.join("\n")
      end

      def compact_instance_helper_yard_doc(name)
        <<~YARD.chomp("\n")
          # @!method self.#{name}
          #   @!macro #{compact_macro_name("finder")}
        YARD
      end

      def compact_predicate_helper_yard_doc(name)
        <<~YARD.chomp("\n")
          # @!method #{name}?
          #   @!macro #{compact_macro_name("predicate")}
        YARD
      end

      # The attribute macro cannot carry the @return tag because the return type differs
      # per method, so each attribute method adds its own.
      def compact_attribute_helper_yard_doc(name, attribute_name)
        <<~YARD.chomp("\n")
          # @!method self.#{name}_#{attribute_name}
          #   @!macro #{compact_macro_name("attribute")}
          #   @return [#{attribute_yard_return_type(name, attribute_name)}]
        YARD
      end

      def compact_macro_name(suffix)
        "support_table_#{klass.name.underscore.tr("/", "_")}_#{suffix}"
      end

      def attribute_yard_return_type(name, attribute_name)
        TypeInference.yard_type(TypeInference.value_type(klass, name, attribute_name))
      end
    end
  end
end

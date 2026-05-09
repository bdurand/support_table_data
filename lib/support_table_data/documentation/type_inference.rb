# frozen_string_literal: true

module SupportTableData
  module Documentation
    # Infers documentation types for the dynamically-defined attribute helpers
    # by reading the canonical value out of the parsed data file and
    # inspecting its class. This avoids invoking the generated method, which
    # may have been wrapped (e.g. deprecated) to raise.
    module TypeInference
      module_function

      # Determine the documentation type for a named-instance attribute
      # helper by looking up the attribute value in the model's named
      # instance data and returning its class. Returns nil when the
      # attribute is not defined for the named instance.
      #
      # @param klass [Class] The model class
      # @param name [String, Symbol] The named instance name
      # @param attribute_name [String, Symbol] The attribute name
      # @return [Class, nil]
      def value_type(klass, name, attribute_name)
        return nil unless klass.respond_to?(:named_instance_data)

        data = klass.named_instance_data(name)
        return nil unless data.is_a?(Hash) && data.key?(attribute_name.to_s)

        data[attribute_name.to_s].class
      end

      # Map a Ruby value class to a YARD type string.
      def yard_type(value_class)
        case value_class&.name
        when "String" then "String"
        when "Integer" then "Integer"
        when "Float" then "Float"
        when "TrueClass", "FalseClass" then "Boolean"
        when "Array" then "Array"
        when "Hash" then "Hash"
        when "NilClass", nil then "Object"
        else value_class.name
        end
      end

      # Map a Ruby value class to an RBS type string.
      def rbs_type(value_class)
        case value_class&.name
        when "String" then "String"
        when "Integer" then "Integer"
        when "Float" then "Float"
        when "TrueClass", "FalseClass" then "bool"
        when "Array" then "Array[untyped]"
        when "Hash" then "Hash[untyped, untyped]"
        when "NilClass", nil then "untyped"
        else value_class.name
        end
      end
    end
  end
end

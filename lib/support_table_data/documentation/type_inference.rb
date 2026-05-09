# frozen_string_literal: true

module SupportTableData
  module Documentation
    # Infers documentation types for the dynamically-defined attribute helpers
    # by calling the generated method and inspecting the class of the value
    # it returns. The values returned by these helpers are frozen literals from
    # the parsed data file, so this does not require a database connection.
    #
    # This module must not be used on finder helpers (e.g. `Color.red`), which
    # call `find_by!` and would hit the database.
    module TypeInference
      module_function

      # Determine the documentation type for an attribute helper by calling
      # the method and looking at the class of the returned value. Returns
      # nil when the method is not defined.
      #
      # @param klass [Class] The model class
      # @param method_name [String, Symbol] The class method name to call
      # @return [Class, nil]
      def value_type(klass, method_name)
        return nil unless klass.respond_to?(method_name)

        klass.public_send(method_name).class
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

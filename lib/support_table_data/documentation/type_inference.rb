# frozen_string_literal: true

module SupportTableData
  module Documentation
    # Maps ActiveRecord column types to documentation type strings.
    module TypeInference
      module_function

      # Look up the ActiveRecord column type symbol for an attribute, or nil if
      # type inference is disabled, the class does not expose columns_hash, or
      # the column is not defined on the table (e.g. virtual attributes).
      #
      # Raises SupportTableData::DocumentationConnectionError when the lookup
      # fails because no database connection is available and
      # SupportTableData.infer_documentation_types is true.
      def column_type(klass, attribute_name)
        return nil unless SupportTableData.infer_documentation_types
        return nil unless klass.respond_to?(:columns_hash)

        column = klass.columns_hash[attribute_name.to_s]
        column&.type
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid => e
        raise SupportTableData::DocumentationConnectionError.new(klass, e)
      end

      # Map a column type symbol to a YARD type string.
      def yard_type(column_type)
        case column_type
        when :string, :text, :uuid, :inet, :cidr then "String"
        when :integer, :bigint then "Integer"
        when :decimal then "BigDecimal"
        when :float then "Float"
        when :boolean then "Boolean"
        when :date then "Date"
        when :datetime, :timestamp, :time then "Time"
        when :json, :jsonb, :hstore then "Hash"
        when :binary then "String"
        else "Object"
        end
      end

      # Map a column type symbol to an RBS type string.
      def rbs_type(column_type)
        case column_type
        when :string, :text, :uuid, :inet, :cidr then "String"
        when :integer, :bigint then "Integer"
        when :decimal then "BigDecimal"
        when :float then "Float"
        when :boolean then "bool"
        when :date then "Date"
        when :datetime, :timestamp, :time then "Time"
        when :json, :jsonb, :hstore then "Hash[untyped, untyped]"
        when :binary then "String"
        else "untyped"
        end
      end
    end
  end
end

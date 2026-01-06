# frozen_string_literal: true

module SupportTableData
  # Error class that is raised when validation fails when loading support table data.
  # It provides more context than the standard ActiveRecord::RecordInvalid to help identify
  # which record caused the validation failure.
  class ValidationError < StandardError
    def initialize(invalid_record)
      key_attribute = invalid_record.class.support_table_key_attribute
      key_value = invalid_record[key_attribute]
      message = "Validation failed for #{invalid_record.class} with #{key_attribute}: #{key_value.inspect} - " \
                "#{invalid_record.errors.full_messages.join(", ")}"
      super(message)
    end
  end
end

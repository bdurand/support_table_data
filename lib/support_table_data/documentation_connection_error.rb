# frozen_string_literal: true

module SupportTableData
  # Raised when documentation generation needs to read column types from the
  # database to fill in `@return` tags / RBS signatures, but no database
  # connection is available. Users who run the documentation tasks in
  # environments without a database (e.g. a lint-only CI job) can opt out by
  # setting `SupportTableData.infer_documentation_types = false`.
  class DocumentationConnectionError < StandardError
    def initialize(klass, original)
      message = <<~MSG.strip
        Could not load column types for #{klass.name} from the database while generating documentation (#{original.class}: #{original.message}).

        Documentation generation reads ActiveRecord column types so the produced docs use specific return types (String, Integer, Boolean, ...) instead of generic Object/untyped.

        To resolve, either:
          1. Ensure a database connection is available when running the documentation tasks (e.g. run `bin/rails db:prepare` or set DATABASE_URL).
          2. Disable type inference globally:
               SupportTableData.infer_documentation_types = false
             The generated docs will fall back to generic Object/untyped return types.
      MSG
      super(message)
    end
  end
end

# frozen_string_literal: true

module SupportTableData
  module Documentation
    class SourceFile
      attr_reader :klass, :path

      BEGIN_YARD_COMMENT = "# Begin YARD docs for support_table_data"
      END_YARD_COMMENT = "# End YARD docs for support_table_data"
      YARD_COMMENT_REGEX = /^(?<indent>[ \t]*)#{BEGIN_YARD_COMMENT}.*^[ \t]*#{END_YARD_COMMENT}$/m
      CLASS_DEF_REGEX = /^[ \t]*class [a-zA-Z_0-9:]+.*?$/
      UPDATE_COMMAND_COMMENT = "# To update these docs, run `bundle exec rake support_table_data:yard_docs`"

      # Initialize a new source file representation.
      #
      # @param klass [Class] The model class
      # @param path [Pathname] The path to the source file
      def initialize(klass, path)
        @klass = klass
        @path = path
        @source = nil
      end

      # Return the source code of the file.
      #
      # @return [String]
      def source
        @source ||= @path.read
      end

      # Return the source code without any generated YARD documentation.
      #
      # @return [String]
      def source_without_yard_docs
        "#{source.sub(YARD_COMMENT_REGEX, "").rstrip}#{trailing_newline}"
      end

      # Return the source code with the generated YARD documentation added.
      # The YARD docs are identified by a begin and end comment block. By default
      # the generated docs are added to the end of the file by reopening the class
      # definition. You can move the comment block inside the original class
      # if desired.
      #
      # @return [String]
      def source_with_yard_docs
        yard_docs = YardDoc.new(klass).named_instance_yard_docs
        return source if yard_docs.nil?

        existing_yard_docs = source.match(YARD_COMMENT_REGEX)
        if existing_yard_docs
          indent = existing_yard_docs[:indent]
          has_class_def = existing_yard_docs.to_s.match?(CLASS_DEF_REGEX)
          yard_docs = yard_docs.lines.map { |line| line.blank? ? "\n" : "#{indent}#{"  " if has_class_def}#{line}" }.join

          updated_source = source[0, existing_yard_docs.begin(0)]
          updated_source << "#{indent}#{BEGIN_YARD_COMMENT}\n"
          updated_source << "#{indent}#{UPDATE_COMMAND_COMMENT}\n"
          updated_source << "#{indent}# rubocop:disable all\n"
          updated_source << "#{indent}class #{klass.name}\n" if has_class_def
          updated_source << yard_docs
          updated_source << "\n#{indent}end" if has_class_def
          updated_source << "\n#{indent}# rubocop:enable all"
          updated_source << "\n#{indent}#{END_YARD_COMMENT}"
          updated_source << source[existing_yard_docs.end(0)..-1]
          updated_source
        else
          yard_comments = <<~SOURCE.chomp("\n")
            #{BEGIN_YARD_COMMENT}
            #{UPDATE_COMMAND_COMMENT}
            # rubocop:disable all
            class #{klass.name}
            #{yard_docs.lines.map { |line| line.blank? ? "\n" : "  #{line}" }.join}
            end
            # rubocop:enable all
            #{END_YARD_COMMENT}
          SOURCE
          "#{source.rstrip}\n\n#{yard_comments}#{trailing_newline}"
        end
      end

      # Check if the YARD documentation in the source file is up to date.
      #
      # @return [Boolean]
      def yard_docs_up_to_date?
        source == source_with_yard_docs
      end

      # Check if the source file has any YARD documentation added by support_table_data.
      #
      # @return [Boolean]
      def has_yard_docs?
        source.match?(YARD_COMMENT_REGEX)
      end

      private

      def trailing_newline
        source.end_with?("\n") ? "\n" : ""
      end
    end
  end
end

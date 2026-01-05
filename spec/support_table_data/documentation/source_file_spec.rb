# frozen_string_literal: true

require "spec_helper"

RSpec.describe SupportTableData::Documentation::SourceFile do
  let(:color_path) { Pathname.new(File.expand_path("../../models/color.rb", __dir__)) }
  let(:group_path) { Pathname.new(File.expand_path("../../models/group.rb", __dir__)) }

  describe "#source" do
    it "reads and caches the file content" do
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      source = source_file.source

      expect(source).to be_a(String)
      expect(source).to include("class Color < ActiveRecord::Base")

      # Verify caching - should return same object
      expect(source_file.source).to equal(source)
    end
  end

  describe "#source_without_yard_docs" do
    it "removes existing YARD documentation between markers" do
      source_with_docs = <<~RUBY
        class Color < ActiveRecord::Base
          include SupportTableData

          # Begin YARD docs for support_table_data
          class Color
            # Some YARD docs
          end
          # End YARD docs for support_table_data
        end
      RUBY

      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_with_docs)

      result = source_file.source_without_yard_docs

      expect(result).to include("class Color < ActiveRecord::Base")
      expect(result).to include("include SupportTableData")
      expect(result).not_to include("Begin YARD docs")
      expect(result).not_to include("Some YARD docs")
      expect(result).not_to include("End YARD docs")
    end

    it "preserves trailing newline if present in original" do
      source_with_newline = "class Color\nend\n"
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_with_newline)

      result = source_file.source_without_yard_docs

      expect(result).to end_with("\n")
    end

    it "preserves no trailing newline if absent in original" do
      source_without_newline = "class Color\nend"
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_without_newline)

      result = source_file.source_without_yard_docs

      expect(result).not_to end_with("\n")
    end

    it "returns original source if no YARD docs present" do
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      original = source_file.source
      result = source_file.source_without_yard_docs

      # Both should have same content (though not necessarily same object)
      expect(result.strip).to eq(original.strip)
    end
  end

  describe "#source_with_yard_docs" do
    it "adds YARD documentation with proper markers" do
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      result = source_file.source_with_yard_docs

      expect(result).to include("# Begin YARD docs for support_table_data")
      expect(result).to include("# End YARD docs for support_table_data")

      # Color has named instances: black, blue, green, red
      expect(result).to include("# @!method self.black")
      expect(result).to include("# @!method black?")
    end

    it "preserves trailing newline from original file" do
      source_with_newline = "class Color\nend\n"
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_with_newline)

      result = source_file.source_with_yard_docs

      expect(result).to end_with("\n")
    end

    it "preserves no trailing newline if absent in original" do
      source_without_newline = "class Color\nend"
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_without_newline)

      result = source_file.source_with_yard_docs

      # When appending new docs, they don't add trailing newline if original doesn't have one
      expect(result).not_to end_with("\n")
    end

    it "replaces existing YARD docs with fresh ones when markers include class definition" do
      source_with_old_docs = <<~RUBY
        class Color < ActiveRecord::Base
          include SupportTableData

          # Begin YARD docs for support_table_data
          class Color
            # Old YARD docs
          end
          # End YARD docs for support_table_data
        end
      RUBY

      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_with_old_docs)

      result = source_file.source_with_yard_docs

      expect(result).to include("# Begin YARD docs for support_table_data")
      expect(result).to include("# End YARD docs for support_table_data")
      expect(result).not_to include("# Old YARD docs")
      expect(result).to include("# @!method self.black")
      # Should include class definition since original had it
      expect(result).to match(/# Begin YARD docs.*class Color.*# @!method self\.black.*end.*# End YARD docs/m)
    end

    it "replaces existing YARD docs inline when markers do not include class definition" do
      source_with_inline_docs = <<~RUBY
        class Color < ActiveRecord::Base
          include SupportTableData

          # Begin YARD docs for support_table_data
          # Old inline YARD docs
          # End YARD docs for support_table_data

          def some_method
          end
        end
      RUBY

      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_with_inline_docs)

      result = source_file.source_with_yard_docs

      expect(result).to include("# Begin YARD docs for support_table_data")
      expect(result).to include("# End YARD docs for support_table_data")
      expect(result).not_to include("# Old inline YARD docs")
      expect(result).to include("# @!method self.black")
      # Should NOT reopen class definition since original didn't have it
      expect(result).not_to match(/# Begin YARD docs.*class Color.*# End YARD docs/m)
      # Verify the class definition remains at the top and inline docs are between markers
      expect(result).to match(/class Color < ActiveRecord::Base.*# Begin YARD docs.*# @!method self\.black.*# End YARD docs.*def some_method/m)
    end

    it "preserves indentation when replacing inline YARD docs" do
      source_with_indented_docs = <<~RUBY
        class Color < ActiveRecord::Base
          include SupportTableData

          # Begin YARD docs for support_table_data
          # Old docs
          # End YARD docs for support_table_data
        end
      RUBY

      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_with_indented_docs)

      result = source_file.source_with_yard_docs

      # Check that the generated docs maintain the 2-space indentation
      expect(result).to include("  # Begin YARD docs for support_table_data")
      expect(result).to include("  # @!method self.black")
      expect(result).to include("  # End YARD docs for support_table_data")
    end
  end

  describe "#yard_docs_up_to_date?" do
    it "returns true when YARD docs match current generated docs" do
      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      up_to_date_source = source_file.source_with_yard_docs

      allow(source_file).to receive(:source).and_return(up_to_date_source)

      expect(source_file.yard_docs_up_to_date?).to be true
    end

    it "returns false when YARD docs are missing" do
      source_without_docs = <<~RUBY
        class Color < ActiveRecord::Base
          include SupportTableData
        end
      RUBY

      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_without_docs)

      expect(source_file.yard_docs_up_to_date?).to be false
    end

    it "returns false when YARD docs are outdated" do
      source_with_old_docs = <<~RUBY
        class Color < ActiveRecord::Base
          include SupportTableData

          # Begin YARD docs for support_table_data
          class Color
            # Old outdated docs
          end
          # End YARD docs for support_table_data
        end
      RUBY

      source_file = SupportTableData::Documentation::SourceFile.new(Color, color_path)
      allow(source_file).to receive(:source).and_return(source_with_old_docs)

      expect(source_file.yard_docs_up_to_date?).to be false
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe SupportTableData::Documentation::YardDoc do
  describe "#instance_helper_yard_doc" do
    it "generates YARD documentation for a named instance class method" do
      doc = SupportTableData::Documentation::YardDoc.new(Color)
      result = doc.instance_helper_yard_doc("red")

      expect(result).to include("# Find the named instance +red+ from the database.")
      expect(result).to include("# @return [Color]")
      expect(result).to include("# @raise [ActiveRecord::RecordNotFound] if the record does not exist")
      expect(result).to include("# @!method self.red")
    end

    it "uses the correct class name in return type" do
      doc = SupportTableData::Documentation::YardDoc.new(Group)
      result = doc.instance_helper_yard_doc("primary")

      expect(result).to include("# @return [Group]")
    end
  end

  describe "#predicate_helper_yard_doc" do
    it "generates YARD documentation for a named instance predicate method" do
      doc = SupportTableData::Documentation::YardDoc.new(Color)
      result = doc.predicate_helper_yard_doc("red")

      expect(result).to include("# Check if this record is the named instance +red+.")
      expect(result).to include("# @return [Boolean]")
      expect(result).to include("# @!method red?")
    end
  end

  describe "#attribute_helper_yard_doc" do
    it "uses the column type for the @return tag when the column is known" do
      doc = SupportTableData::Documentation::YardDoc.new(Group)
      result = doc.attribute_helper_yard_doc("primary", "name")

      expect(result).to include("# @return [String]")
    end

    it "falls back to Object when the column is not on the table" do
      doc = SupportTableData::Documentation::YardDoc.new(Group)
      result = doc.attribute_helper_yard_doc("primary", "not_a_real_column")

      expect(result).to include("# @return [Object]")
    end
  end

  describe "#named_instance_yard_docs" do
    it "returns nil when model has no named instances" do
      allow(Color).to receive(:instance_names).and_return([])

      doc = SupportTableData::Documentation::YardDoc.new(Color)
      result = doc.named_instance_yard_docs

      expect(result).to be_nil
    end

    it "generates YARD docs for all named instances" do
      doc = SupportTableData::Documentation::YardDoc.new(Color)
      result = doc.named_instance_yard_docs

      expect(result).not_to be_nil

      # Check for group markers
      expect(result).to include("# @!group Named Instances")
      expect(result).to include("# @!endgroup")

      # Check for named instances (Color has black, blue, green, red)
      expect(result).to include("# Find the named instance +black+ from the database.")
      expect(result).to include("# @!method self.black")
      expect(result).to include("# Check if this record is the named instance +black+.")
      expect(result).to include("# @!method black?")

      expect(result).to include("# Find the named instance +blue+ from the database.")
      expect(result).to include("# @!method self.blue")
    end

    it "includes attribute helper methods when defined" do
      doc = SupportTableData::Documentation::YardDoc.new(Group)
      result = doc.named_instance_yard_docs

      expect(result).not_to be_nil

      # Group has attribute helpers for group_id and name
      # Check for one of Group's instances (e.g., gray, primary, secondary)
      expect(result).to include("# Get the group_id attribute from the data file")
      expect(result).to include("# for the named instance +gray+.")
      expect(result).to include("# @!method self.gray_group_id")
      expect(result).to include("# Get the name attribute from the data file")
      expect(result).to include("# for the named instance +gray+.")
      expect(result).to include("# @!method self.gray_name")
    end

    it "sorts instance names alphabetically" do
      doc = SupportTableData::Documentation::YardDoc.new(Color)
      result = doc.named_instance_yard_docs

      # Color instances should appear in alphabetical order
      # Use more specific patterns to find the first occurrence of each method
      black_pos = result.index("# @!method self.black")
      blue_pos = result.index("# @!method self.blue")
      green_pos = result.index("# @!method self.green")
      red_pos = result.index("# @!method self.red")

      expect(black_pos).to be < blue_pos
      expect(blue_pos).to be < green_pos
      expect(green_pos).to be < red_pos
    end

    context "when there are more named instances than the compact threshold" do
      around do |example|
        original = SupportTableData.compact_yard_threshold
        SupportTableData.compact_yard_threshold = 5
        begin
          example.run
        ensure
          SupportTableData.compact_yard_threshold = original
        end
      end

      it "emits the compact macro form for Hue (9 instances)" do
        doc = SupportTableData::Documentation::YardDoc.new(Hue)
        result = doc.named_instance_yard_docs

        expect(result).not_to be_nil
        expect(result).to include("# @!group Named Instances")
        expect(result).to include("# @!endgroup")

        # Macro definitions are emitted once.
        expect(result).to include("# @!macro [new] support_table_data_finder")
        expect(result).to include("# @!macro [new] support_table_data_predicate")
        # Hue has no attribute helpers, but the attribute macro is still defined.
        expect(result).to include("# @!macro [new] support_table_data_attribute")
        expect(result.scan("# @!macro [new] support_table_data_finder").size).to eq(1)

        # Per-instance entries reference the macros rather than repeating prose.
        expect(result).to include("# @!method self.red")
        expect(result).to include("# @!macro support_table_data_finder red")
        expect(result).to include("# @!method red?")
        expect(result).to include("# @!macro support_table_data_predicate red")
        expect(result).not_to include("# Find the named instance +red+ from the database.")
      end

      it "uses the verbose form when count is at or below the threshold" do
        SupportTableData.compact_yard_threshold = 4
        doc = SupportTableData::Documentation::YardDoc.new(Color)
        result = doc.named_instance_yard_docs

        # Color has 4 instances; with threshold 4 we are NOT above it -> verbose.
        expect(result).to include("# Find the named instance +red+ from the database.")
        expect(result).not_to include("# @!macro [new]")
      end

      it "includes attribute macro invocations with column-derived types" do
        doc = SupportTableData::Documentation::YardDoc.new(Group)
        # Group only has 3 instances normally; force compact form to test attribute output.
        SupportTableData.compact_yard_threshold = 0
        result = doc.named_instance_yard_docs

        # Group has attribute helpers for group_id (integer) and name (string).
        expect(result).to include("# @!macro support_table_data_attribute primary group_id Integer")
        expect(result).to include("# @!macro support_table_data_attribute primary name String")
      end
    end
  end
end

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
  end
end

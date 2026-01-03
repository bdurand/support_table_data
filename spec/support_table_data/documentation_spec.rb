# frozen_string_literal: true

require "spec_helper"

require_relative "../../lib/support_table_data/documentation"

RSpec.describe SupportTableData::Documentation do
  before do
    Color.delete_all
    Group.delete_all
  end

  describe "#instance_helper_yard_doc" do
    it "generates YARD documentation for a named instance class method" do
      doc = SupportTableData::Documentation.new(Color)
      result = doc.instance_helper_yard_doc("red")

      expect(result).to include("# Find the named instance record +red+ from the database.")
      expect(result).to include("# @return [Color] the +red+ record")
      expect(result).to include("# @raise [ActiveRecord::RecordNotFound] if the record does not exist")
      expect(result).to include("# @!method self.red")
    end

    it "uses the correct class name in return type" do
      doc = SupportTableData::Documentation.new(Group)
      result = doc.instance_helper_yard_doc("primary")

      expect(result).to include("# @return [Group] the +primary+ record")
    end
  end

  describe "#predicate_helper_yard_doc" do
    it "generates YARD documentation for a named instance predicate method" do
      doc = SupportTableData::Documentation.new(Color)
      result = doc.predicate_helper_yard_doc("red")

      expect(result).to include("# Check if this record is the +red+ record.")
      expect(result).to include("# @return [Boolean] true if this is the +red+ record, false otherwise")
      expect(result).to include("# @!method red?")
    end
  end

  describe "#class_def_with_yard_docs" do
    it "returns nil when model has no named instances" do
      allow(Color).to receive(:instance_names).and_return([])

      doc = SupportTableData::Documentation.new(Color)
      result = doc.class_def_with_yard_docs

      expect(result).to be_nil
    end

    it "generates YARD docs for all named instances" do
      doc = SupportTableData::Documentation.new(Color)
      result = doc.class_def_with_yard_docs
      puts result

      expect(result).not_to be_nil

      # Check for class definition
      expect(result).to include("class Color")

      # Check for named instances (Color has black, blue, green, red)
      expect(result).to include("# Find the named instance record +black+ from the database.")
      expect(result).to include("# @!method self.black")
      expect(result).to include("# Check if this record is the +black+ record.")
      expect(result).to include("# @!method black?")

      expect(result).to include("# Find the named instance record +blue+ from the database.")
      expect(result).to include("# @!method self.blue")
    end

    it "includes attribute helper methods when defined" do
      doc = SupportTableData::Documentation.new(Group)
      result = doc.class_def_with_yard_docs

      expect(result).not_to be_nil

      # Group has attribute helpers for group_id and name
      # Check for one of Group's instances (e.g., gray, primary, secondary)
      expect(result).to include("# Get the group_id attribute of the +gray+ record.")
      expect(result).to include("# @!method self.gray_group_id")
      expect(result).to include("# Get the name attribute of the +gray+ record.")
      expect(result).to include("# @!method self.gray_name")
    end

    it "sorts instance names alphabetically" do
      doc = SupportTableData::Documentation.new(Color)
      result = doc.class_def_with_yard_docs

      # Color instances should appear in alphabetical order
      black_pos = result.index("self.black")
      blue_pos = result.index("self.blue")
      green_pos = result.index("self.green")
      red_pos = result.index("self.red")

      expect(black_pos).to be < blue_pos
      expect(blue_pos).to be < green_pos
      expect(green_pos).to be < red_pos
    end
  end
end

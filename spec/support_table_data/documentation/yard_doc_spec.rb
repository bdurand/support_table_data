# frozen_string_literal: true

require "spec_helper"

RSpec.describe SupportTableData::Documentation::YardDoc do
  # Run the generated documentation through YARD and return the methods it resolved as a hash
  # of method path (i.e. "Color.red" or "Color#red?") to its sorted list of tags. Generated
  # docs are only useful if YARD actually attaches the tags to the right method, which cannot
  # be verified by matching against the generated text.
  def yard_methods_for(klass)
    begin
      require "yard"
      require "tmpdir"
    rescue LoadError
      skip "yard is not available"
    end

    docs = SupportTableData::Documentation::YardDoc.new(klass).named_instance_yard_docs
    body = docs.split("\n").collect { |line| line.empty? ? line : "  #{line}" }.join("\n")

    Dir.mktmpdir do |dir|
      path = File.join(dir, "#{klass.name.underscore}.rb")
      File.write(path, "class #{klass.name}\n#{body}\nend\n")

      YARD::Registry.clear
      YARD::Registry.load([path], true)
      YARD::Registry.all(:method).each_with_object({}) do |method, hash|
        hash[method.path] = method.tags.collect { |tag| [tag.tag_name, tag.types] }.sort
      end
    end
  ensure
    YARD::Registry.clear if defined?(YARD::Registry)
  end

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

    context "when the model declares support_table_yard_docs = :compact" do
      around do |example|
        original = Color.support_table_yard_docs
        Color.support_table_yard_docs = :compact
        begin
          example.run
        ensure
          Color.support_table_yard_docs = original
        end
      end

      it "emits shared macro definitions and a short block per method that expands them" do
        doc = SupportTableData::Documentation::YardDoc.new(Color)
        result = doc.named_instance_yard_docs

        expect(result).not_to be_nil
        expect(result).to include("# @!group Named Instances")
        expect(result).to include("# @!endgroup")

        expect(result).to include("# @!macro [new] support_table_color_finder\n#   Find this named instance from the database.\n#   @return [Color]")
        expect(result).to include("# @!macro [new] support_table_color_predicate\n#   Check if this record is this named instance.\n#   @return [Boolean]")

        expect(result).to include("# @!method self.red\n#   @!macro support_table_color_finder")
        expect(result).to include("# @!method red?\n#   @!macro support_table_color_predicate")
        expect(result).not_to include("# Find the named instance +red+ from the database.")
      end

      it "generates docs that YARD resolves to the same methods and tags as the full format" do
        compact = yard_methods_for(Color)

        Color.support_table_yard_docs = :full
        full = yard_methods_for(Color)

        expect(compact.keys).to match_array(full.keys)
        expect(compact.keys).to include("Color.red", "Color#red?")

        compact.each do |path, tags|
          expect(tags).to eq(full.fetch(path)), "expected #{path} to have the same tags in both formats"
        end
      end

      it "documents the predicate as an instance method and the finder as a class method" do
        methods = yard_methods_for(Color)

        expect(methods["Color.red"]).to eq([["return", ["Color"]], ["raise", ["ActiveRecord::RecordNotFound"]]].sort)
        expect(methods["Color#red?"]).to eq([["return", ["Boolean"]]])
      end
    end

    context "when the model declares support_table_yard_docs = :compact with attribute helpers" do
      around do |example|
        original = Group.support_table_yard_docs
        Group.support_table_yard_docs = :compact
        begin
          example.run
        ensure
          Group.support_table_yard_docs = original
        end
      end

      it "emits attribute helper methods with data-derived types" do
        doc = SupportTableData::Documentation::YardDoc.new(Group)
        result = doc.named_instance_yard_docs

        # Group has attribute helpers for group_id (integer) and name (string).
        expect(result).to include("# @!method self.primary_group_id\n#   @!macro support_table_group_attribute\n#   @return [Integer]")
        expect(result).to include("# @!method self.primary_name\n#   @!macro support_table_group_attribute\n#   @return [String]")
      end

      it "generates attribute helper docs that YARD resolves with the right return types" do
        methods = yard_methods_for(Group)

        expect(methods["Group.primary_group_id"]).to eq([["return", ["Integer"]]])
        expect(methods["Group.primary_name"]).to eq([["return", ["String"]]])
      end
    end

    context "when the model declares support_table_yard_docs = :none" do
      around do |example|
        original = Color.support_table_yard_docs
        Color.support_table_yard_docs = :none
        begin
          example.run
        ensure
          Color.support_table_yard_docs = original
        end
      end

      it "returns nil even when the model has named instances" do
        doc = SupportTableData::Documentation::YardDoc.new(Color)
        expect(doc.named_instance_yard_docs).to be_nil
      end
    end
  end

  describe "Color.support_table_yard_docs=" do
    it "rejects unknown values" do
      expect {
        Color.support_table_yard_docs = :verbose
      }.to raise_error(ArgumentError, /support_table_yard_docs must be one of/)
    end

    it "accepts :full, :compact, and :none" do
      original = Color.support_table_yard_docs
      begin
        %i[full compact none].each do |value|
          expect { Color.support_table_yard_docs = value }.not_to raise_error
          expect(Color.support_table_yard_docs).to eq(value)
        end
      ensure
        Color.support_table_yard_docs = original
      end
    end
  end
end

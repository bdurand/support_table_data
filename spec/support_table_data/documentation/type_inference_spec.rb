# frozen_string_literal: true

require "spec_helper"

RSpec.describe SupportTableData::Documentation::TypeInference do
  describe ".value_type" do
    it "returns the class of the value from the named instance data" do
      # Group has named_instance_attribute_helpers :group_id, :name
      expect(described_class.value_type(Group, "primary", "name")).to eq(String)
      expect(described_class.value_type(Group, "primary", "group_id")).to eq(Integer)
    end

    it "returns nil when the attribute is not present in the named instance data" do
      expect(described_class.value_type(Group, "primary", "not_a_real_attribute")).to be_nil
    end

    it "returns nil when the named instance does not exist" do
      expect(described_class.value_type(Group, "not_a_real_instance", "name")).to be_nil
    end

    it "does not invoke the generated helper methods" do
      # The generated method may be wrapped (e.g. deprecated) to raise, so we
      # must read the value from the data file rather than calling the method.
      expect(Group).not_to receive(:primary)
      expect(Group).not_to receive(:primary_name)
      described_class.value_type(Group, "primary", "name")
    end
  end

  describe ".yard_type" do
    it "maps common value classes to YARD type strings" do
      expect(described_class.yard_type(String)).to eq("String")
      expect(described_class.yard_type(Integer)).to eq("Integer")
      expect(described_class.yard_type(Float)).to eq("Float")
      expect(described_class.yard_type(TrueClass)).to eq("Boolean")
      expect(described_class.yard_type(FalseClass)).to eq("Boolean")
      expect(described_class.yard_type(Array)).to eq("Array")
      expect(described_class.yard_type(Hash)).to eq("Hash")
    end

    it "falls back to Object for nil or NilClass" do
      expect(described_class.yard_type(nil)).to eq("Object")
      expect(described_class.yard_type(NilClass)).to eq("Object")
    end

    it "uses the class name for other classes" do
      expect(described_class.yard_type(Date)).to eq("Date")
    end
  end

  describe ".rbs_type" do
    it "maps common value classes to RBS type strings" do
      expect(described_class.rbs_type(String)).to eq("String")
      expect(described_class.rbs_type(Integer)).to eq("Integer")
      expect(described_class.rbs_type(Float)).to eq("Float")
      expect(described_class.rbs_type(TrueClass)).to eq("bool")
      expect(described_class.rbs_type(FalseClass)).to eq("bool")
      expect(described_class.rbs_type(Array)).to eq("Array[untyped]")
      expect(described_class.rbs_type(Hash)).to eq("Hash[untyped, untyped]")
    end

    it "falls back to untyped for nil or NilClass" do
      expect(described_class.rbs_type(nil)).to eq("untyped")
      expect(described_class.rbs_type(NilClass)).to eq("untyped")
    end
  end
end

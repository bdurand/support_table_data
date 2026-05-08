# frozen_string_literal: true

require "spec_helper"

RSpec.describe SupportTableData::Documentation::TypeInference do
  describe ".column_type" do
    it "returns the AR column type symbol for a known column" do
      expect(described_class.column_type(Group, "name")).to eq(:string)
      expect(described_class.column_type(Group, "group_id")).to eq(:integer)
    end

    it "returns nil for an unknown column" do
      expect(described_class.column_type(Group, "not_a_real_column")).to be_nil
    end

    it "returns nil for a class that does not respond to columns_hash" do
      klass = Class.new
      expect(described_class.column_type(klass, "anything")).to be_nil
    end

    context "when SupportTableData.infer_documentation_types is false" do
      around do |example|
        original = SupportTableData.infer_documentation_types
        SupportTableData.infer_documentation_types = false
        begin
          example.run
        ensure
          SupportTableData.infer_documentation_types = original
        end
      end

      it "returns nil without consulting the database" do
        expect(Group).not_to receive(:columns_hash)
        expect(described_class.column_type(Group, "name")).to be_nil
      end
    end

    context "when no database connection is available" do
      it "raises a DocumentationConnectionError with resolution guidance" do
        allow(Group).to receive(:columns_hash)
          .and_raise(ActiveRecord::ConnectionNotEstablished, "No connection pool")

        expect {
          described_class.column_type(Group, "name")
        }.to raise_error(SupportTableData::DocumentationConnectionError) do |error|
          expect(error.message).to include("Group")
          expect(error.message).to include("ConnectionNotEstablished")
          expect(error.message).to include("infer_documentation_types = false")
        end
      end

      it "returns nil silently when type inference is disabled" do
        original = SupportTableData.infer_documentation_types
        SupportTableData.infer_documentation_types = false
        begin
          # columns_hash is not even called; nothing to raise.
          expect(described_class.column_type(Group, "name")).to be_nil
        ensure
          SupportTableData.infer_documentation_types = original
        end
      end
    end
  end

  describe ".yard_type" do
    it "maps common column types to documentation strings" do
      expect(described_class.yard_type(:string)).to eq("String")
      expect(described_class.yard_type(:integer)).to eq("Integer")
      expect(described_class.yard_type(:boolean)).to eq("Boolean")
      expect(described_class.yard_type(:date)).to eq("Date")
      expect(described_class.yard_type(:datetime)).to eq("Time")
      expect(described_class.yard_type(:json)).to eq("Hash")
    end

    it "falls back to Object for nil or unknown types" do
      expect(described_class.yard_type(nil)).to eq("Object")
      expect(described_class.yard_type(:something_exotic)).to eq("Object")
    end
  end

  describe ".rbs_type" do
    it "maps common column types to RBS type strings" do
      expect(described_class.rbs_type(:string)).to eq("String")
      expect(described_class.rbs_type(:integer)).to eq("Integer")
      expect(described_class.rbs_type(:boolean)).to eq("bool")
      expect(described_class.rbs_type(:date)).to eq("Date")
      expect(described_class.rbs_type(:datetime)).to eq("Time")
    end

    it "falls back to untyped for nil or unknown types" do
      expect(described_class.rbs_type(nil)).to eq("untyped")
      expect(described_class.rbs_type(:something_exotic)).to eq("untyped")
    end
  end
end

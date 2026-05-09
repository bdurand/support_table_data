# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe SupportTableData::Documentation::RbsFile do
  let(:color_path) { Pathname.new(File.expand_path("../../models/color.rb", __dir__)) }

  describe ".signatures_path_for" do
    it "places the sig file at <project_root>/sig/<relative_path>.rbs" do
      Dir.mktmpdir do |tmp|
        root = Pathname.new(tmp)
        FileUtils.touch(root.join("Gemfile"))
        model_dir = root.join("app", "models")
        model_dir.mkpath
        source = model_dir.join("widget.rb")
        source.write("class Widget; end\n")

        sig_path = described_class.signatures_path_for(source)

        expect(sig_path).to eq(root.join("sig", "app", "models", "widget.rbs"))
      end
    end

    it "honours SupportTableData.rbs_signatures_path when set" do
      Dir.mktmpdir do |tmp|
        root = Pathname.new(tmp)
        FileUtils.touch(root.join("Gemfile"))
        source = root.join("app", "models", "widget.rb")
        source.dirname.mkpath
        source.write("class Widget; end\n")

        original = SupportTableData.rbs_signatures_path
        begin
          SupportTableData.rbs_signatures_path = root.join("custom_sigs").to_s
          sig_path = described_class.signatures_path_for(source)

          expect(sig_path).to eq(Pathname.new(root.join("custom_sigs", "app", "models", "widget.rbs").to_s))
        ensure
          SupportTableData.rbs_signatures_path = original
        end
      end
    end
  end

  describe "#up_to_date?" do
    it "returns false when the file is missing" do
      Dir.mktmpdir do |tmp|
        FileUtils.touch(File.join(tmp, "Gemfile"))
        source = Pathname.new(tmp).join("app", "models", "color.rb")
        source.dirname.mkpath
        FileUtils.cp(color_path, source)

        rbs_file = described_class.new(Color, source)
        expect(rbs_file.up_to_date?).to be false
      end
    end

    it "returns true after writing" do
      Dir.mktmpdir do |tmp|
        FileUtils.touch(File.join(tmp, "Gemfile"))
        source = Pathname.new(tmp).join("app", "models", "color.rb")
        source.dirname.mkpath
        FileUtils.cp(color_path, source)

        rbs_file = described_class.new(Color, source)
        rbs_file.write!

        expect(rbs_file.up_to_date?).to be true
      end
    end
  end

  describe "#write!" do
    it "creates the parent sig directory and writes the signatures" do
      Dir.mktmpdir do |tmp|
        FileUtils.touch(File.join(tmp, "Gemfile"))
        source = Pathname.new(tmp).join("app", "models", "color.rb")
        source.dirname.mkpath
        FileUtils.cp(color_path, source)

        rbs_file = described_class.new(Color, source)
        expect(rbs_file.write!).to be true

        expect(rbs_file.path).to exist
        expect(rbs_file.path.read).to include("class Color")
        expect(rbs_file.path.read).to include("def self.red: () -> Color")
      end
    end

    it "returns false when there are no instances to document" do
      Dir.mktmpdir do |tmp|
        FileUtils.touch(File.join(tmp, "Gemfile"))
        source = Pathname.new(tmp).join("app", "models", "color.rb")
        source.dirname.mkpath
        FileUtils.cp(color_path, source)

        allow(Color).to receive(:instance_names).and_return([])
        rbs_file = described_class.new(Color, source)

        expect(rbs_file.write!).to be false
        expect(rbs_file.path).not_to exist
      end
    end
  end

  describe "#remove!" do
    it "deletes the file when it exists" do
      Dir.mktmpdir do |tmp|
        FileUtils.touch(File.join(tmp, "Gemfile"))
        source = Pathname.new(tmp).join("app", "models", "color.rb")
        source.dirname.mkpath
        FileUtils.cp(color_path, source)

        rbs_file = described_class.new(Color, source)
        rbs_file.write!
        expect(rbs_file.path).to exist

        expect(rbs_file.remove!).to be true
        expect(rbs_file.path).not_to exist
      end
    end

    it "returns false when there is nothing to remove" do
      Dir.mktmpdir do |tmp|
        FileUtils.touch(File.join(tmp, "Gemfile"))
        source = Pathname.new(tmp).join("app", "models", "color.rb")
        source.dirname.mkpath
        FileUtils.cp(color_path, source)

        rbs_file = described_class.new(Color, source)
        expect(rbs_file.remove!).to be false
      end
    end
  end
end

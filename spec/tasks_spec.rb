# frozen_string_literal: true

require "spec_helper"
require "rake"

RSpec.describe "support_table_data rake tasks" do
  let(:out) { StringIO.new }
  let(:color_model_path) { File.join(__dir__, "models", "color.rb") }

  before do
    # Create a fresh Rake application for each test
    Rake.application = Rake::Application.new
    load File.join(__dir__, "..", "lib", "tasks", "support_table_data.rake")
    Rake::Task.define_task(:environment)
    allow(ActiveRecord::Base).to receive(:logger).and_return(Logger.new(out))

    # Mock Rails for task execution
    rails_app = double("Rails.application")
    rails_config = double("Rails.application.config")
    allow(rails_config).to receive(:eager_load).and_return(true)  # Already loaded in spec_helper
    allow(rails_config).to receive(:paths).and_return("app/models" => [File.join(__dir__, "models")])
    allow(rails_app).to receive(:config).and_return(rails_config)
    stub_const("Rails", double("Rails", application: rails_app))
  end

  describe "sync" do
    it "loads all tables" do
      expect(SupportTableData).to receive(:sync_all!).and_call_original
      Rake.application.invoke_task "support_table_data:sync"
      [Hue, Group, Color].each do |klass|
        expect(out.string).to match(/Synchronized support table model #{klass.name} in \d+ms/)
      end
    end
  end

  describe "yard_docs:add" do
    it "adds YARD documentation to models with named instances" do
      # Mock stdout to capture puts
      allow($stdout).to receive(:puts)

      # Track which files would be written to
      written_files = []
      allow_any_instance_of(Pathname).to receive(:write) do |instance, content|
        written_files << {path: instance.to_s, content: content}
      end

      # Run the task
      Rake.application.invoke_task "support_table_data:yard_docs:add"

      # Verify that at least one model had documentation added
      expect(written_files).not_to be_empty
      expect($stdout).to have_received(:puts).at_least(:once)

      # Verify the written content looks correct (check one example)
      color_write = written_files.find { |f| f[:path].include?("color.rb") }
      expect(color_write).not_to be_nil
      expect(color_write[:content]).to include("# Begin YARD docs for support_table_data")
      expect(color_write[:content]).to include("@!method self.red")
    end

    it "applies only to the specified file path when provided" do
      allow($stdout).to receive(:puts)

      written_files = []
      allow_any_instance_of(Pathname).to receive(:write) do |instance, content|
        written_files << {path: instance.to_s, content: content}
      end

      Rake::Task["support_table_data:yard_docs:add"].invoke(color_model_path)

      expect(written_files).not_to be_empty
      expect(written_files.map { |f| f[:path] }.uniq).to eq([color_model_path])
    end
  end

  describe "yard_docs:remove" do
    it "removes YARD documentation from models" do
      # Mock stdout to capture puts
      allow($stdout).to receive(:puts)

      # Track which files would be written to
      written_files = []
      allow_any_instance_of(Pathname).to receive(:write) do |instance, content|
        written_files << {path: instance.to_s, content: content}
      end

      # Mock that files have YARD docs
      allow_any_instance_of(SupportTableData::Documentation::SourceFile)
        .to receive(:has_yard_docs?).and_return(true)

      # Run the task
      Rake.application.invoke_task "support_table_data:yard_docs:remove"

      # Verify that files were written to
      expect(written_files).not_to be_empty
      expect($stdout).to have_received(:puts).at_least(:once)

      # Verify the written content doesn't include YARD docs (check one example)
      color_write = written_files.find { |f| f[:path].include?("color.rb") }
      expect(color_write).not_to be_nil
      expect(color_write[:content]).not_to include("# Begin YARD docs for support_table_data")
    end

    it "applies only to the specified file path when provided" do
      allow($stdout).to receive(:puts)

      written_files = []
      allow_any_instance_of(Pathname).to receive(:write) do |instance, content|
        written_files << {path: instance.to_s, content: content}
      end

      allow_any_instance_of(SupportTableData::Documentation::SourceFile)
        .to receive(:has_yard_docs?).and_return(true)

      Rake::Task["support_table_data:yard_docs:remove"].invoke(color_model_path)

      expect(written_files).not_to be_empty
      expect(written_files.map { |f| f[:path] }.uniq).to eq([color_model_path])
    end
  end

  describe "rbs:add" do
    it "writes RBS files for models with named instances" do
      allow($stdout).to receive(:puts)

      written_files = []
      allow_any_instance_of(SupportTableData::Documentation::RbsFile).to receive(:write!) do |instance|
        written_files << {path: instance.path.to_s, klass: instance.klass.name}
        true
      end
      allow_any_instance_of(SupportTableData::Documentation::RbsFile)
        .to receive(:up_to_date?).and_return(false)

      Rake.application.invoke_task "support_table_data:rbs:add"

      expect(written_files).not_to be_empty
      expect(written_files.map { |f| f[:klass] }).to include("Color")
    end

    it "applies only to the specified file path when provided" do
      allow($stdout).to receive(:puts)

      written_files = []
      allow_any_instance_of(SupportTableData::Documentation::RbsFile).to receive(:write!) do |instance|
        written_files << {path: instance.path.to_s, klass: instance.klass.name}
        true
      end
      allow_any_instance_of(SupportTableData::Documentation::RbsFile)
        .to receive(:up_to_date?).and_return(false)

      Rake::Task["support_table_data:rbs:add"].invoke(color_model_path)

      expect(written_files.map { |f| f[:klass] }).to eq(["Color"])
    end
  end

  describe "rbs:remove" do
    it "removes generated RBS files for support table models" do
      allow($stdout).to receive(:puts)

      removed = []
      allow_any_instance_of(SupportTableData::Documentation::RbsFile).to receive(:remove!) do |instance|
        removed << instance.klass.name
        true
      end

      Rake.application.invoke_task "support_table_data:rbs:remove"

      expect(removed).not_to be_empty
    end
  end

  describe "rbs:verify" do
    it "passes when all signatures are up to date" do
      allow($stdout).to receive(:puts)
      allow_any_instance_of(SupportTableData::Documentation::RbsFile)
        .to receive(:up_to_date?).and_return(true)

      Rake.application.invoke_task "support_table_data:rbs:verify"

      expect($stdout).to have_received(:puts).with("All support table models have up to date RBS signatures.")
    end

    it "raises when signatures are out of date" do
      allow($stdout).to receive(:puts)
      allow_any_instance_of(SupportTableData::Documentation::RbsFile)
        .to receive(:up_to_date?).and_return(false)

      expect {
        Rake.application.invoke_task "support_table_data:rbs:verify"
      }.to raise_error(RuntimeError)
    end
  end

  describe "yard_docs:verify" do
    it "verifies YARD documentation is up to date" do
      allow($stdout).to receive(:puts)
      allow_any_instance_of(SupportTableData::Documentation::SourceFile)
        .to receive(:yard_docs_up_to_date?).and_return(true)

      # Run the task
      Rake.application.invoke_task "support_table_data:yard_docs:verify"

      # Verify output indicates all docs are up to date
      expect($stdout).to have_received(:puts).with("All support table models have up to date YARD documentation.")
    end

    it "raises an error if any YARD documentation is out of date" do
      allow($stdout).to receive(:puts)
      allow_any_instance_of(SupportTableData::Documentation::SourceFile)
        .to receive(:yard_docs_up_to_date?).and_return(false)

      # Run the task and expect an error
      expect {
        Rake.application.invoke_task "support_table_data:yard_docs:verify"
      }.to raise_error(RuntimeError)

      # Verify output indicates which docs are out of date
      expect($stdout).to have_received(:puts).at_least(:once)
    end

    it "verifies only the specified file path when provided" do
      allow($stdout).to receive(:puts)

      expect_any_instance_of(SupportTableData::Documentation::SourceFile)
        .to receive(:yard_docs_up_to_date?).once.and_return(true)

      Rake::Task["support_table_data:yard_docs:verify"].invoke(color_model_path)

      expect($stdout).to have_received(:puts).with("YARD documentation is up to date for #{color_model_path}.")
    end
  end
end

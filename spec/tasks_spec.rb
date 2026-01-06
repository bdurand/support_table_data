# frozen_string_literal: true

require_relative "spec_helper"
require "rake"

RSpec.describe "support_table_data rake tasks" do
  let(:out) { StringIO.new }

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

  describe "add_yard_docs" do
    it "adds YARD documentation to models with named instances" do
      require_relative "../lib/support_table_data/documentation"
      require_relative "../lib/tasks/utils"

      # Mock stdout to capture puts
      allow($stdout).to receive(:puts)

      # Track which files would be written to
      written_files = []
      allow_any_instance_of(Pathname).to receive(:write) do |instance, content|
        written_files << {path: instance.to_s, content: content}
      end

      # Run the task
      Rake.application.invoke_task "support_table_data:add_yard_docs"

      # Verify that at least one model had documentation added
      expect(written_files).not_to be_empty
      expect($stdout).to have_received(:puts).at_least(:once)

      # Verify the written content looks correct (check one example)
      color_write = written_files.find { |f| f[:path].include?("color.rb") }
      expect(color_write).not_to be_nil
      expect(color_write[:content]).to include("# Begin YARD docs for support_table_data")
      expect(color_write[:content]).to include("@!method self.red")
    end
  end

  describe "verify_yard_docs" do
    it "verifies YARD documentation is up to date" do
      require_relative "../lib/support_table_data/documentation"
      require_relative "../lib/tasks/utils"

      allow($stdout).to receive(:puts)
      allow_any_instance_of(SupportTableData::Documentation::SourceFile)
        .to receive(:yard_docs_up_to_date?).and_return(true)

      # Run the task
      Rake.application.invoke_task "support_table_data:verify_yard_docs"

      # Verify output indicates all docs are up to date
      expect($stdout).to have_received(:puts).with("All support table models have up to date YARD documentation.")
    end

    it "raises an error if any YARD documentation is out of date" do
      require_relative "../lib/support_table_data/documentation"
      require_relative "../lib/tasks/utils"

      allow($stdout).to receive(:puts)
      allow_any_instance_of(SupportTableData::Documentation::SourceFile)
        .to receive(:yard_docs_up_to_date?).and_return(false)

      # Run the task and expect an error
      expect {
        Rake.application.invoke_task "support_table_data:verify_yard_docs"
      }.to raise_error(RuntimeError)

      # Verify output indicates which docs are out of date
      expect($stdout).to have_received(:puts).at_least(:once)
    end
  end
end

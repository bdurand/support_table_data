# frozen_string_literal: true

require_relative "spec_helper"
require "rake"

describe "support_table_data" do
  let(:rake) { Rake::Application.new }

  before do
    Rake.application = rake
    Rake.application.rake_require("lib/tasks/support_table_data", [File.join(__dir__, "..")])
    Rake::Task.define_task(:environment)
  end

  describe "sync" do
    it "loads all tables" do
      expect(SupportTableData).to receive(:sync_all!).and_call_original
      Rake.application.invoke_task "support_table_data:sync"
    end
  end
end

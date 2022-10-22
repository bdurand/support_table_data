# frozen_string_literal: true

require_relative "spec_helper"
require "rake"

describe "support_table_data" do
  let(:rake) { Rake::Application.new }
  let(:out) { StringIO.new }

  before do
    Rake.application = rake
    Rake.application.rake_require("lib/tasks/support_table_data", [File.join(__dir__, "..")])
    Rake::Task.define_task(:environment)
    allow(ActiveRecord::Base).to receive(:logger).and_return(Logger.new(out))
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
end

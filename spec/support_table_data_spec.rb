# frozen_string_literal: true

require_relative "spec_helper"

describe SupportTableData do
  let(:red) { Color.find_by(name: "Red") }
  let(:green) { Color.find_by(name: "Green") }
  let(:blue) { Color.find_by(name: "Blue") }
  let(:purple) { Color.find_by(name: "Purple") }
  let(:light_gray) { Color.find_by(name: "Light Gray") }
  let(:dark_gray) { Color.find_by(name: "Dark Gray") }

  describe "sync_table_data!" do
    it "loads data from YAML and JSON files" do
      Color.sync_table_data!

      expect(red.id).to eq 1
      expect(red.value).to eq 0xFF0000

      expect(green.id).to eq 2
      expect(green.value).to eq 0x00FF00

      expect(blue.id).to eq 3
      expect(blue.value).to eq 0x0000FF
    end

    it "updates existing data from the values in the data files" do
      color = Color.new(name: "Pink", comment: "on the reddish side")
      color.id = 1
      color.save!
      Color.sync_table_data!
      color.reload
      expect(color.name).to eq "Red"
      expect(color.value).to eq 0xFF0000
      expect(color.comment).to eq "on the reddish side"
    end

    it "does not delete extra rows not in the data files" do
      color = Color.new(name: "Pink")
      color.id = 10
      color.save!
      Color.sync_table_data!
      expect(Color.find_by(id: 10)).to eq color
    end

    it "combines data when a record is defined across multiple data files" do
      Color.sync_table_data!
      expect(purple.name).to eq "Purple"
      expect(purple.value).to eq 0x800080
    end
  end

  describe "define_instances_from" do
    it "defines class methods to load records by a column value" do
      Color.sync_table_data!
      expect(Color.red).to eq red
      expect(Color.light_gray).to eq light_gray
      expect(Color.dark_gray).to eq dark_gray
    end
  end

  describe "define_predicates_from" do
    it "defines predicate methods for comparing an attribute" do
      Color.sync_table_data!
      expect(red.red?).to eq true
      expect(red.dark_gray?).to eq false
      expect(dark_gray.dark_gray?).to eq true
    end
  end
end

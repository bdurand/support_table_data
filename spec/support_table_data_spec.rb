# frozen_string_literal: true

require_relative "spec_helper"

describe SupportTableData do
  let(:red) { Color.find_by(name: "Red") }
  let(:green) { Color.find_by(name: "Green") }
  let(:blue) { Color.find_by(name: "Blue") }
  let(:yellow) { Color.find_by(name: "Yellow") }
  let(:purple) { Color.find_by(name: "Purple") }
  let(:light_gray) { Color.find_by(name: "Light Gray") }
  let(:dark_gray) { Color.find_by(name: "Dark Gray") }
  let(:white) { Color.find_by(name: "White") }

  describe "sync_table_data!" do
    it "loads data from YAML, JSON, or CSV files" do
      Color.sync_table_data!

      expect(red.id).to eq 1
      expect(red.value).to eq 0xFF0000

      expect(green.id).to eq 2
      expect(green.value).to eq 0x00FF00

      expect(blue.id).to eq 3
      expect(blue.value).to eq 0x0000FF

      expect(yellow.id).to eq 11
      expect(yellow.value).to eq 0xFFFF00

      expect(white.id).to eq 14
      expect(white.value).to eq 0xFFFFFF
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

  describe "named instances" do
    it "defines class methods to load records by a column value" do
      Color.sync_table_data!
      expect(Color.red).to eq red
      expect(Color.blue).to eq blue
    end

    it "raises an error if the instance doesn't exist" do
      expect { Color.red }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "defines predicate methods for comparing an attribute" do
      Color.sync_table_data!
      expect(red.red?).to eq true
      expect(red.blue?).to eq false
    end

    it "does not define helper methods when the name begins with an underscore" do
      expect(Color.respond_to?(:_)).to eq false
      expect(red.respond_to?(:_?)).to eq false
    end
  end

  describe "instance_names" do
    it "gets a list of instance names" do
      expect(Color.instance_names).to match_array ["black", "blue", "red", "green"]
    end
  end

  describe "instance_keys" do
    it "gets a list of key attribute values for all instances" do
      expect(Color.instance_keys).to match_array [1, 3, 12, 14, 2, 13, 4, 9, 8, 10, 11]
    end
  end

  describe "protected_instance?" do
    it "returns true if the instance came from a data file" do
      red = Color.new
      red.id = 1
      orange = Color.new
      orange.id = 11
      brown = Color.new
      brown.id = 50
      expect(red.protected_instance?).to eq true
      expect(orange.protected_instance?).to eq true
      expect(brown.protected_instance?).to eq false
    end
  end
end

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
      Hue.sync_table_data!
      Group.sync_table_data!
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
  end

  describe "sync_all!" do
    it "loads data from YAML, JSON, or CSV files" do
      SupportTableData.sync_all!

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
      SupportTableData.sync_all!
      color.reload
      expect(color.name).to eq "Red"
      expect(color.value).to eq 0xFF0000
      expect(color.comment).to eq "on the reddish side"
    end

    it "does not delete extra rows not in the data files" do
      color = Color.new(name: "Pink")
      color.id = 10
      color.save!
      SupportTableData.sync_all!
      expect(Color.find_by(id: 10)).to eq color
    end

    it "combines data when a record is defined across multiple data files" do
      SupportTableData.sync_all!
      expect(purple.name).to eq "Purple"
      expect(purple.value).to eq 0x800080
    end

    it "returns a list of changes" do
      changes = Group.sync_table_data!
      expect(changes).to eq([
        {"group_id" => [nil, 1], "name" => [nil, "primary"]},
        {"group_id" => [nil, 2], "name" => [nil, "secondary"]},
        {"group_id" => [nil, 3], "name" => [nil, "gray"]}
      ])
      expect(Group.sync_table_data!).to eq([])

      all_changes = SupportTableData.sync_all!
      expect(all_changes[Group]).to eq([])
      expect(all_changes[Hue]).to_not eq([])
      expect(all_changes[Color]).to_not eq([])
    end

    it "can be called with a list of classes to include" do
      expect { SupportTableData.sync_all!(Color) }.to_not raise_error
    end

    it "ignores anonomous classes" do
      Class.new(ActiveRecord::Base)
      expect { SupportTableData.sync_all! }.to_not raise_error
    end
  end

  describe "named instances" do
    it "defines class methods to load records by a column value" do
      SupportTableData.sync_all!
      expect(Color.red).to eq red
      expect(Color.blue).to eq blue
    end

    it "raises an error if the instance doesn't exist" do
      expect { Color.red }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can load an instance by name" do
      SupportTableData.sync_all!
      expect(Color.named_instance("red")).to eq red
      expect(Color.named_instance(:red)).to eq red
      expect { Color.named_instance("pink") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "defines predicate methods for comparing an attribute" do
      SupportTableData.sync_all!
      expect(red.red?).to eq true
      expect(red.blue?).to eq false
    end

    it "does not define helper methods when the name begins with an underscore" do
      expect(Color.respond_to?(:_)).to eq false
      expect(red.respond_to?(:_?)).to eq false
    end

    it "raises an error if the method is already defined" do
      expect { Invalid.add_support_table_data("invalid.yml") }.to raise_error(ArgumentError)
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

  describe "named_instance_attribute_helpers" do
    it "adds helper methods for each attribute on named instances" do
      expect(Group.primary_group_id).to eq 1
      expect(Group.secondary_group_id).to eq 2
      expect(Group.gray_group_id).to eq 3
      expect(Group.primary_name).to eq "primary"
      expect(Group.secondary_name).to eq "secondary"
      expect(Group.gray_name).to eq "gray"
    end

    it "can get a list of the defined attribute helpers" do
      expect(Group.support_table_attribute_helpers).to match_array ["group_id", "name"]
      expect(Color.support_table_attribute_helpers).to match_array []
    end

    it "returns frozen values" do
      expect(Group.primary_group_id).to be_frozen
      expect(Group.primary_name).to be_frozen
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

  describe "support_table_classes" do
    it "gets a list of all loaded support table classes with dependencies listed first" do
      expect(SupportTableData.support_table_classes).to eq [Shade, Group, Hue, Color, Invalid]
    end
  end

  describe "support_table_data" do
    it "returns an array with all the attributes" do
      data = Color.support_table_data
      expect(data.size).to eq 11
      expect(data).to include({
        "id" => 1,
        "name" => "Red",
        "hex" => "0xFF0000",
        "group_name" => "primary",
        "hue_name" => "red"
      })
    end

    it "returns a fresh copy every call" do
      data_1 = Color.support_table_data
      data_2 = Color.support_table_data
      expect(data_1.object_id).to_not eq data_2.object_id
      expect(data_1.map(&:object_id)).to_not match_array data_2.map(&:object_id)
      expect(data_1.map { |attributes| attributes.values.map(&:object_id) }.flatten).to_not match_array data_2.map { |attributes| attributes.values.map(&:object_id) }.flatten
    end
  end

  describe "named_instance_data" do
    it "returns a hash of the named instances" do
      data = Color.named_instance_data("red")
      expect(data["name"]).to eq "Red"
    end

    it "can use a symbol as the name" do
      data = Color.named_instance_data(:red)
      expect(data["name"]).to eq "Red"
    end

    it "returns a fresh copy every call" do
      data_1 = Color.named_instance_data("red")
      data_2 = Color.named_instance_data("red")
      expect(data_1.object_id).to_not eq data_2.object_id
      expect(data_1.values.map(&:object_id)).to_not match_array data_2.values.map(&:object_id)
    end
  end
end

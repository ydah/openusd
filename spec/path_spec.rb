# frozen_string_literal: true

RSpec.describe OpenUSD::Path do
  describe ".parse" do
    it "parses absolute prim and property paths" do
      path = described_class.parse("/World/Cube.points")

      expect(path).to be_absolute
      expect(path).to be_property
      expect(path.property_name).to eq("points")
      expect(path.prim_path.to_s).to eq("/World/Cube")
    end

    it "returns an existing path unchanged" do
      path = described_class.parse("/World")

      expect(described_class.parse(path)).to equal(path)
    end

    it "rejects malformed paths" do
      invalid = ["", "/World/", "/World//Cube", "/123", "/World.bad::name", ".prop"]

      invalid.each do |value|
        expect { described_class.parse(value) }.to raise_error(OpenUSD::PathError)
      end
    end
  end

  it "navigates parents, children, and properties" do
    cube = described_class.parse("/World").child("Cube")

    expect(cube.to_s).to eq("/World/Cube")
    expect(cube.parent.to_s).to eq("/World")
    expect(cube.property("xformOp:translate").parent).to eq(cube)
    expect(described_class.parse("/World").parent.to_s).to eq("/")
    expect(described_class.parse("/").parent).to be_nil
  end

  it "rejects invalid child operations" do
    expect { described_class.parse("/World.attr").child("Nope") }.to raise_error(OpenUSD::PathError)
    expect { described_class.parse("/World").property("bad:name:") }.to raise_error(OpenUSD::PathError)
  end

  it "is immutable, hashable, and comparable" do
    one = described_class.parse("/A")
    same = described_class.parse("/A")

    expect({ one => :value }[same]).to eq(:value)
    expect(one).to be_frozen
    expect(one).to be < described_class.parse("/B")
  end
end

# frozen_string_literal: true

RSpec.describe OpenUSD::Types do
  it "validates and normalizes scalar types" do
    expect(described_class.coerce("bool", true)).to be(true)
    expect(described_class.coerce("int", 12)).to eq(12)
    expect(described_class.coerce("double", 2)).to eq(2.0)
    expect(described_class.coerce("string", "hello")).to eq("hello")
    expect(described_class.coerce("token", "render")).to be_a(OpenUSD::Token)
    expect(described_class.coerce("asset", "mesh.usda")).to eq(OpenUSD::AssetPath.new("mesh.usda"))
  end

  it "checks integer ranges" do
    expect { described_class.coerce("uint", -1) }.to raise_error(OpenUSD::TypeError)
    expect { described_class.coerce("int", 2**31) }.to raise_error(OpenUSD::TypeError)
  end

  it "validates vectors, matrices, and arrays" do
    expect(described_class.coerce("point3f", [1, 2, 3])).to eq([1.0, 2.0, 3.0])
    expect(described_class.coerce("int[]", [1, 2])).to eq([1, 2])
    expect(described_class.coerce("matrix2d", [[1, 0], [0, 1]])).to eq([[1.0, 0.0], [0.0, 1.0]])
    expect { described_class.coerce("float3", [1, 2]) }.to raise_error(OpenUSD::TypeError)
  end

  it "preserves unknown types for forward compatibility" do
    value = Object.new

    expect(described_class.coerce("futureType", value)).to equal(value)
    expect(described_class).not_to be_known("futureType")
  end

  it "exposes type inspection and validation" do
    expect(described_class).to be_array("float[]")
    expect(described_class.base_type("float[]")).to eq("float")
    expect(described_class.validate!("double3", [1, 2, 3])).to eq([1.0, 2.0, 3.0])
  end
end

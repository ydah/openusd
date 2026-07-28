# frozen_string_literal: true

require "tmpdir"

RSpec.describe OpenUSD::Format::Usda::Writer do
  let(:fixture_dir) { File.expand_path("fixtures", __dir__) }

  it "round-trips every project fixture with semantic equality" do
    Dir[File.join(fixture_dir, "*.usda")].each do |path|
      original = OpenUSD::Layer.open(path)
      reparsed = OpenUSD::Format::Usda::Parser.parse(original.to_usda)

      expect(reparsed).to eq(original), "round-trip failed for #{File.basename(path)}"
    end
  end

  it "produces deterministic, escaped USDA" do
    layer = OpenUSD::Layer.create("scene.usda")
    layer.metadata["defaultPrim"] = "World"
    prim = OpenUSD::PrimSpec.new("World", type_name: "Xform")
    prim.add_property(OpenUSD::AttributeSpec.new("label", "string", default: "line\n\"quoted\""))
    layer.add_root_prim(prim)

    expected = <<~USDA
      #usda 1.0
      (
          defaultPrim = "World"
      )

      def Xform "World"
      {
          string label = "line\\n\\"quoted\\""
      }
    USDA
    expect(described_class.new.write_to_string(layer)).to eq(expected)
  end

  it "exports and reopens a layer" do
    source = File.join(fixture_dir, "minimal.usda")
    layer = OpenUSD::Layer.open(source)

    Dir.mktmpdir do |directory|
      destination = File.join(directory, "copy.usda")
      expect(layer.export(destination)).to equal(layer)
      expect(OpenUSD::Layer.open(destination)).to eq(layer)
    end
  end

  it "round-trips matrices and non-finite numbers" do
    source = <<~USDA
      #usda 1.0
      def Xform "World" {
          matrix2d transform = ((1, 0), (0, 1))
          double negativeInfinity = -inf
          double notANumber = nan
      }
    USDA
    layer = OpenUSD::Format::Usda::Parser.parse(source)
    output = layer.to_usda
    reparsed = OpenUSD::Format::Usda::Parser.parse(output)

    expect(reparsed.prim_at("/World").property_named("transform").default).to eq([[1.0, 0.0], [0.0, 1.0]])
    expect(reparsed.prim_at("/World").property_named("negativeInfinity").default).to eq(-Float::INFINITY)
    expect(reparsed.prim_at("/World").property_named("notANumber").default).to be_nan
  end
end

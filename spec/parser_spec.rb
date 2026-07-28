# frozen_string_literal: true

RSpec.describe OpenUSD::Format::Usda::Parser do
  let(:fixture_dir) { File.expand_path("fixtures", __dir__) }
  let(:fixture_paths) { Dir[File.join(fixture_dir, "{,upstream/}*.usda")] }

  it "parses every project and upstream fixture" do
    layers = fixture_paths.map { |path| OpenUSD::Layer.open(path) }

    expect(layers.length).to eq(21)
    expect(layers).to all(be_a(OpenUSD::Layer))
  end

  it "parses layer metadata, dictionaries, references, and variants" do
    metadata = OpenUSD::Layer.open(File.join(fixture_dir, "dictionary.usda")).metadata
    reference = OpenUSD::Layer.open(File.join(fixture_dir, "references.usda")).root_prims.first.references.first
    variant_prim = OpenUSD::Layer.open(File.join(fixture_dir, "variants.usda")).root_prims.first

    expect(metadata["customLayerData"]).to eq("creator" => "openusd", "revision" => 1)
    expect(reference.asset_path.path).to eq("minimal.usda")
    expect(reference.prim_path.to_s).to eq("/World")
    expect(variant_prim.variant_sets.fetch("color").keys).to contain_exactly("red", "blue")
  end

  it "parses attributes, time samples, connections, and relationships" do
    source = <<~USDA
      #usda 1.0
      def Xform "World" {
          uniform float weight = 0.5
          float driven.connect = </Driver.output>
          float animated.timeSamples = { 10: 2, 0: 1 }
          rel target = [</A>, </B>]
      }
    USDA
    prim = described_class.parse(source).root_prims.first

    expect(prim.property_named("weight").variability).to eq(:uniform)
    expect(prim.property_named("driven").connections.first.to_s).to eq("/Driver.output")
    expect(prim.property_named("animated").time_samples.keys).to eq([0.0, 10.0])
    expect(prim.property_named("target").targets.map(&:to_s)).to eq(["/A", "/B"])
  end

  it "preserves unknown types and metadata" do
    source = <<~USDA
      #usda 1.0
      (
          futureSetting = "retained"
      )
      def FutureType "Object" {
          custom futureValue data = "opaque"
      }
    USDA
    layer = described_class.parse(source)

    expect(layer.metadata["futureSetting"]).to eq("retained")
    expect(layer.prim_at("/Object").property_named("data").default).to eq("opaque")
  end

  it "preserves the standalone layer comment" do
    source = <<~USDA
      #usda 1.0
      (
          "A layer comment."
          customLayerData = {
              string owner = "pipeline"
          }
      )
    USDA
    layer = described_class.parse(source)

    expect(layer.metadata["comment"]).to eq("A layer comment.")
    expect(described_class.parse(layer.to_usda)).to eq(layer)
  end

  it "merges repeated declarations of one property spec" do
    source = <<~USDA
      #usda 1.0
      def Mesh "Mesh" {
          color3f[] primvars:displayColor (
              interpolation = "vertex"
          )
          color3f[] primvars:displayColor.timeSamples = {
              8.3: [(1, 0, 0)]
          }
      }
    USDA
    layer = described_class.parse(source)
    attribute = layer.prim_at("/Mesh").property_named("primvars:displayColor")

    expect(attribute.metadata["interpolation"]).to eq("vertex")
    expect(attribute.time_samples).to eq(8.3 => [[1.0, 0.0, 0.0]])
    expect(described_class.parse(layer.to_usda)).to eq(layer)
  end

  it "uses the numeric-array path for large scalar and vector values" do
    integers = (0...1_000).to_a
    points = (0...100).map { |index| "(#{index}, #{index + 1}, #{index + 2})" }
    source = <<~USDA
      #usda 1.0
      def Mesh "Mesh" {
          int[] indices = [#{integers.join(", ")}]
          point3f[] points = [#{points.join(", ")}]
      }
    USDA
    prim = described_class.parse(source).prim_at("/Mesh")

    expect(prim.property_named("indices").default).to eq(integers)
    expect(prim.property_named("points").default.last).to eq([99.0, 100.0, 101.0])
  end

  it "reports malformed inputs with source positions" do
    invalid_sources = [
      "",
      "#usda 2.0",
      "#usda 1.0\n?",
      "#usda 1.0\n/* open",
      "#usda 1.0\n<open",
      "#usda 1.0\ndef Xform \"Open\" {",
      "#usda 1.0\ndef Xform \"bad-name\" {}",
      "#usda 1.0\ndef Xform \"A\" { float value = }",
      "#usda 1.0\ndef Xform \"A\" { float3 value = (1, 2) }",
      "#usda 1.0\ndef Xform \"A\" { rel = </A> }"
    ]

    invalid_sources.each do |source|
      expect { described_class.parse(source, file: "broken.usda") }
        .to raise_error(OpenUSD::ParseError, /broken\.usda:\d+:\d+:/)
    end
  end
end

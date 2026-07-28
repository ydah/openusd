# frozen_string_literal: true

RSpec.describe OpenUSD::Format::Usda::Parser do
  let(:fixture_dir) { File.expand_path("fixtures", __dir__) }

  it "parses every project fixture" do
    layers = Dir[File.join(fixture_dir, "*.usda")].map { |path| OpenUSD::Layer.open(path) }

    expect(layers.length).to eq(10)
    expect(layers.sum { |layer| layer.each_prim.count }).to eq(13)
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

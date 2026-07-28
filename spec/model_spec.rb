# frozen_string_literal: true

RSpec.describe "OpenUSD core model" do
  let(:layer) { OpenUSD::Layer.create("scene.usda") }
  let(:world) { OpenUSD::PrimSpec.new("World", type_name: "Xform") }

  it "builds and looks up a prim hierarchy" do
    mesh = OpenUSD::PrimSpec.new("Mesh", type_name: "Mesh")
    world.add_child(mesh)
    layer.add_root_prim(world)

    expect(layer.prim_at("/World/Mesh")).to equal(mesh)
    expect(layer.each_prim.map(&:path).map(&:to_s)).to eq(["/World", "/World/Mesh"])
    expect { world.add_child(OpenUSD::PrimSpec.new("Mesh")) }.to raise_error(OpenUSD::PathError)
  end

  it "stores validated attributes and sorted time samples" do
    attribute = OpenUSD::AttributeSpec.new("size", "double", default: 2)
    attribute.set(3, time: 24)
    attribute.set(1, time: 0)
    attribute.connections = ["/Driver.output"]

    expect(attribute.default).to eq(2.0)
    expect(attribute.time_samples.keys).to eq([0.0, 24.0])
    expect(attribute.connections.first).to eq(OpenUSD::Path.parse("/Driver.output"))
    expect { attribute.type_name = "int" }.to raise_error(OpenUSD::TypeError)
    expect(attribute.clear_default).not_to be_default_authored
  end

  it "stores relationships without duplicate targets" do
    relationship = OpenUSD::RelationshipSpec.new("material:binding", targets: ["/Material"])

    relationship.add_target("/Material")
    relationship.add_target("/Other")

    expect(relationship.targets.map(&:to_s)).to eq(["/Material", "/Other"])
  end

  it "stores references, metadata, variants, and sublayers" do
    world.add_reference("asset.usda", "/Root")
    world.variant_sets["look"] = { "red" => [] }
    layer.add_root_prim(world)
    layer.metadata["defaultPrim"] = "World"
    layer.metadata["subLayers"] = [OpenUSD::AssetPath.new("weak.usda")]

    expect(layer.default_prim).to equal(world)
    expect(layer.sub_layer_paths).to eq(["weak.usda"])
    expect(world.references.first.prim_path.to_s).to eq("/Root")
    expect(layer).to eq(OpenUSD::Layer.new(nil, metadata: layer.metadata, root_prims: [world]))
  end

  it "rejects malformed model input" do
    expect { OpenUSD::PrimSpec.new("bad-name") }.to raise_error(OpenUSD::PathError)
    expect { OpenUSD::AttributeSpec.new("a", "float", variability: :sometimes) }
      .to raise_error(OpenUSD::TypeError)
    expect { world.add_property(Object.new) }.to raise_error(OpenUSD::TypeError)
    expect { layer.prim_at("/World.attr") }.to raise_error(OpenUSD::PathError)
  end
end

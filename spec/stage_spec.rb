# frozen_string_literal: true

RSpec.describe OpenUSD::Stage do
  it "creates, edits, traverses, and removes prims" do
    stage = described_class.create_in_memory
    stage.define_prim("/World", "Xform")
    cube = stage.define_prim("/World/Cube", "Cube")
    cube.create_attribute("size", "double").set(2)
    cube.create_relationship("target").add_target("/World")
    cube.metadata["kind"] = "component"
    cube.attribute("size").metadata["documentation"] = "diameter"
    cube.type_name = "Sphere"

    expect(stage.traverse.map { |prim| prim.path.to_s }).to eq(["/World", "/World/Cube"])
    expect(cube.parent.path.to_s).to eq("/World")
    expect(cube.type_name).to eq("Sphere")
    expect(cube.metadata["kind"]).to eq("component")
    expect(cube.attribute("size").get).to eq(2.0)
    expect(cube.attribute("size").metadata["documentation"]).to eq("diameter")
    expect(cube.relationship("target").targets.map(&:to_s)).to eq(["/World"])

    stage.remove_prim("/World/Cube")
    expect(stage.prim_at("/World/Cube")).to be_nil
  end

  it "sets and interpolates time samples" do
    stage = described_class.create_in_memory
    attribute = stage.define_prim("/Animated", "Xform").create_attribute("value", "double")
    attribute.set(0, time: 0)
    attribute.set(10, time: 10)

    expect(attribute.get(time: 5)).to eq(5.0)
    expect(attribute.get(time: -1)).to eq(0.0)
    expect(attribute.time_samples.keys).to eq([0.0, 10.0])
  end

  it "composes sublayers with stronger root opinions" do
    Dir.mktmpdir do |directory|
      weak = OpenUSD::Layer.create(File.join(directory, "weak.usda"))
      weak_prim = OpenUSD::PrimSpec.new("World", type_name: "Scope")
      weak_prim.add_property(OpenUSD::AttributeSpec.new("value", "int", default: 1))
      connected = OpenUSD::AttributeSpec.new("connected", "float")
      connected.connections = ["/Driver.output"]
      weak_prim.add_property(connected)
      sampled = OpenUSD::AttributeSpec.new("sampled", "float")
      sampled.time_samples = { 0 => 1 }
      weak_prim.add_property(sampled)
      weak_prim.add_property(OpenUSD::RelationshipSpec.new("target", targets: ["/Target"]))
      weak.add_root_prim(weak_prim)
      weak.save

      root = OpenUSD::Layer.create(File.join(directory, "root.usda"))
      root.metadata["subLayers"] = [OpenUSD::AssetPath.new("weak.usda")]
      root_prim = OpenUSD::PrimSpec.new("World", type_name: "Xform", specifier: :over)
      root_prim.add_property(OpenUSD::AttributeSpec.new("value", "int", default: 2))
      disconnected = OpenUSD::AttributeSpec.new("connected", "float")
      disconnected.connections = []
      root_prim.add_property(disconnected)
      unsampled = OpenUSD::AttributeSpec.new("sampled", "float")
      unsampled.time_samples = {}
      root_prim.add_property(unsampled)
      root_prim.add_property(OpenUSD::RelationshipSpec.new("target", targets: []))
      root.add_root_prim(root_prim)
      root.save

      stage = described_class.open(root.identifier)
      expect(stage.prim_at("/World").type_name).to eq("Xform")
      expect(stage.prim_at("/World").attribute("value").get).to eq(2)
      expect(stage.prim_at("/World").attribute("connected").connections).to be_empty
      expect(stage.prim_at("/World").attribute("sampled").time_samples).to be_empty
      expect(stage.prim_at("/World").relationship("target").targets).to be_empty
      expect(stage.layer_stack.length).to eq(2)
    end
  end

  it "maps referenced prim hierarchies and detects cycles" do
    Dir.mktmpdir do |directory|
      asset = OpenUSD::Layer.create(File.join(directory, "asset.usda"))
      asset.metadata["defaultPrim"] = "Model"
      model = OpenUSD::PrimSpec.new("Model", type_name: "Xform")
      model.add_child(OpenUSD::PrimSpec.new("Geometry", type_name: "Scope"))
      asset.add_root_prim(model)
      asset.save

      root = OpenUSD::Layer.create(File.join(directory, "root.usda"))
      instance = OpenUSD::PrimSpec.new("Instance", type_name: "Xform")
      instance.add_reference("asset.usda")
      root.add_root_prim(instance)
      root.save

      stage = described_class.open(root.identifier)
      expect(stage.prim_at("/Instance/Geometry").type_name).to eq("Scope")

      asset.root_prims.first.add_reference("root.usda", "/Instance")
      asset.save
      expect { described_class.open(root.identifier).traverse.to_a }.to raise_error(OpenUSD::CompositionError, /cycle/)
    end
  end

  it "selects authored variants" do
    stage = described_class.open(File.expand_path("fixtures/variants.usda", __dir__))
    model = stage.prim_at("/Model")

    model.set_variant_selection("color", "blue")

    expect(model.attribute("displayColor").get).to eq([0.0, 0.0, 1.0])
    expect { model.set_variant_selection("color", "green") }.to raise_error(OpenUSD::CompositionError)
  end

  it "validates edit targets and property kinds" do
    stage = described_class.create_in_memory
    prim = stage.define_prim("/World")
    prim.create_attribute("value", "int")

    expect { stage.edit_target = OpenUSD::Layer.create("other.usda") }.to raise_error(OpenUSD::CompositionError)
    expect { prim.create_relationship("value") }.to raise_error(OpenUSD::TypeError)
    expect { stage.define_prim("relative") }.to raise_error(OpenUSD::PathError)
  end

  it "preserves edits authored into a sublayer across recomposition" do
    Dir.mktmpdir do |directory|
      weak = OpenUSD::Layer.create(File.join(directory, "weak.usda"))
      weak.add_root_prim(OpenUSD::PrimSpec.new("World", type_name: "Xform"))
      weak.save
      root = OpenUSD::Layer.create(File.join(directory, "root.usda"))
      root.metadata["subLayers"] = [OpenUSD::AssetPath.new("weak.usda")]
      root.save

      stage = described_class.open(root.identifier)
      stage.edit_target = stage.layer_stack.last
      stage.define_prim("/World/FromEditTarget", "Scope")

      expect(stage.prim_at("/World/FromEditTarget").type_name).to eq("Scope")
      expect(stage.layer_stack.last).to equal(stage.edit_target)
    end
  end
end

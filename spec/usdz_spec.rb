# frozen_string_literal: true

RSpec.describe OpenUSD::Format::Usdz do
  let(:fixture) { File.expand_path("fixtures/layer_metadata.usda", __dir__) }

  it "packs stored entries with 64-byte data alignment and reads them" do
    Dir.mktmpdir do |directory|
      texture = File.join(directory, "texture.bin")
      package = File.join(directory, "scene.usdz")
      File.binwrite(texture, "\x00\x01texture")

      described_class::Writer.pack(
        package,
        root: fixture,
        assets: [{ source: texture, path: "textures/texture.bin" }]
      )
      reader = described_class::Reader.new(package)

      expect(reader.entries.map(&:name)).to eq(["layer_metadata.usda", "textures/texture.bin"])
      expect(reader.entries.map(&:data_offset)).to all(satisfy { |offset| (offset % 64).zero? })
      expect(reader.entry("textures/texture.bin").data).to eq("\x00\x01texture")
      expect(OpenUSD::Layer.open(package).default_prim.name).to eq("World")
    end
  end

  it "extracts entries below the requested destination" do
    Dir.mktmpdir do |directory|
      package = File.join(directory, "scene.usdz")
      destination = File.join(directory, "unpacked")
      described_class::Writer.pack(package, root: fixture)

      expect(described_class::Reader.unpack(package, destination: destination)).to eq(["layer_metadata.usda"])
      expect(File.binread(File.join(destination, "layer_metadata.usda"))).to eq(File.binread(fixture))
    end
  end

  it "exports an in-memory stage directly as USDZ" do
    Dir.mktmpdir do |directory|
      package = File.join(directory, "generated.usdz")
      stage = OpenUSD::Stage.create_in_memory
      stage.define_prim("/World", "Xform")
      stage.root_layer.metadata["defaultPrim"] = "World"

      stage.export(package)

      expect(OpenUSD::Stage.open(package).default_prim.type_name).to eq("Xform")
    end
  end

  it "resolves layers referenced inside a package" do
    Dir.mktmpdir do |directory|
      child_path = File.join(directory, "child.usda")
      root_path = File.join(directory, "root.usda")
      package = File.join(directory, "composed.usdz")

      child = OpenUSD::Layer.create(child_path)
      child.metadata["defaultPrim"] = "Model"
      model = OpenUSD::PrimSpec.new("Model", type_name: "Scope")
      model.add_child(OpenUSD::PrimSpec.new("Geometry", type_name: "Mesh"))
      child.add_root_prim(model)
      child.save

      root = OpenUSD::Layer.create(root_path)
      root.metadata["defaultPrim"] = "Instance"
      instance = OpenUSD::PrimSpec.new("Instance", type_name: "Xform")
      instance.add_reference("child.usda")
      root.add_root_prim(instance)
      root.save
      described_class::Writer.pack(package, root: root_path, assets: [child_path])

      expect(OpenUSD::Stage.open(package).prim_at("/Instance/Geometry").type_name).to eq("Mesh")
    end
  end

  it "rejects unsafe package inputs and corrupt archives" do
    Dir.mktmpdir do |directory|
      package = File.join(directory, "bad.usdz")
      expect do
        described_class::Writer.pack(package, root: fixture, assets: [{ source: fixture, path: "../escape.usda" }])
      end.to raise_error(OpenUSD::PackageError, /unsafe/)

      File.binwrite(package, "not a zip")
      expect { described_class::Reader.new(package).entries }.to raise_error(OpenUSD::PackageError, /end-of-directory/)
    end
  end
end

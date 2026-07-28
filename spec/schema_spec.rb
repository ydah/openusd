# frozen_string_literal: true

RSpec.describe OpenUSD::Schema do
  let(:stage) { OpenUSD::Stage.create_in_memory }

  it "defines and retrieves Xform operations" do
    xform = described_class::Xform.define(stage, "/World")
    xform.translate = [1, 2, 3]
    xform.rotate_xyz = [0, 45, 0]
    xform.scale = [2, 2, 2]

    expect(xform.translate).to eq([1.0, 2.0, 3.0])
    expect(xform.prim.attribute("xformOpOrder").get)
      .to eq(%w[xformOp:translate xformOp:rotateXYZ xformOp:scale])
    expect(described_class::Xform.get(stage, "/World").path.to_s).to eq("/World")
  end

  it "authors mesh topology and camera properties" do
    mesh = described_class::Mesh.define(stage, "/Mesh")
    mesh.points = [[0, 0, 0], [1, 0, 0], [0, 1, 0]]
    mesh.face_vertex_counts = [3]
    mesh.face_vertex_indices = [0, 1, 2]
    mesh.subdivision_scheme = "none"
    camera = described_class::Camera.define(stage, "/Camera")
    camera.focal_length = 50
    camera.clipping_range = [0.1, 1000]

    expect(mesh.points.length).to eq(3)
    expect(mesh.subdivision_scheme).to eq("none")
    expect(camera.focal_length).to eq(50.0)
    expect(camera.clipping_range).to eq([0.1, 1000.0])
  end

  it "defines scopes and binds materials" do
    scope = described_class::Scope.define(stage, "/Looks")
    material = described_class::Material.define(stage, "/Looks/Material")
    mesh = described_class::Mesh.define(stage, "/Mesh")

    material.bind(mesh.prim)

    expect(scope.prim.type_name).to eq("Scope")
    expect(mesh.prim.relationship("material:binding").targets).to eq([material.path])
    expect(described_class::Camera.get(stage, "/Mesh")).to be_nil
  end
end

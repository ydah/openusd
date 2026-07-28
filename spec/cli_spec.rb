# frozen_string_literal: true

require "stringio"

RSpec.describe OpenUSD::CLI do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:cli) { described_class.new(stdout: stdout, stderr: stderr) }
  let(:fixture) { File.expand_path("fixtures/layer_metadata.usda", __dir__) }

  it "prints help and version" do
    expect(cli.run(["--help"])).to eq(0)
    expect(stdout.string).to include("cat FILE", "tree FILE", "zip OUTPUT")

    stdout.truncate(0)
    stdout.rewind
    expect(cli.run(["--version"])).to eq(0)
    expect(stdout.string).to eq("openusd #{OpenUSD::VERSION}\n")
  end

  it "formats layers with cat to stdout or a file" do
    expect(cli.run(["cat", fixture])).to eq(0)
    expect(stdout.string).to start_with("#usda 1.0")

    Dir.mktmpdir do |directory|
      output = File.join(directory, "formatted.usda")
      expect(cli.run(["cat", "--output", output, fixture])).to eq(0)
      expect(OpenUSD::Layer.open(output).default_prim.name).to eq("World")
    end
  end

  it "prints the composed prim tree" do
    nested = File.expand_path("fixtures/nested_prims.usda", __dir__)

    expect(cli.run(["tree", nested])).to eq(0)
    expect(stdout.string).to include("World <Xform>", "  Geometry <Scope>", "    Cube <Cube>")
  end

  it "creates USDZ packages" do
    Dir.mktmpdir do |directory|
      package = File.join(directory, "scene.usdz")

      expect(cli.run(["zip", package, fixture])).to eq(0)
      expect(OpenUSD::Layer.open(package).default_prim.name).to eq("World")
      expect(stdout.string).to include(package)
    end
  end

  it "reports usage and library errors" do
    expect(cli.run(["unknown"])).to eq(1)
    expect(stderr.string).to include("unknown command")

    stderr.truncate(0)
    stderr.rewind
    expect(cli.run(["cat"])).to eq(1)
    expect(stderr.string).to include("missing argument")
  end
end

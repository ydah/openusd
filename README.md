# openusd

`openusd` is a Pure Ruby library for reading, composing, editing, and writing
OpenUSD ASCII (`.usda`) and package (`.usdz`) assets. It requires Ruby 3.2 or
newer and has no runtime gem or native-library dependencies.

Version 1.0 focuses on pipeline automation, validation, conversion, and scene
generation. It supports sublayers and references, but it is not a replacement
for the complete C++ OpenUSD composition engine.

## Installation

Add the gem to your bundle:

```bash
bundle add openusd
```

Or install it directly:

```bash
gem install openusd
```

## Create and save a stage

```ruby
require "openusd"

stage = OpenUSD::Stage.create("scene.usda")
stage.define_prim("/World", "Xform")
cube = stage.define_prim("/World/Cube", "Cube")
cube.create_attribute("size", "double").set(2.0)
cube.create_attribute("xformOp:translate", "double3").set([0, 1, 0])
cube.create_relationship("target").set_targets(["/World"])

stage.root_layer.metadata.merge!(
  "defaultPrim" => "World",
  "metersPerUnit" => 1.0,
  "upAxis" => "Y"
)
stage.save
```

## Open and traverse a composed stage

```ruby
stage = OpenUSD::Stage.open("scene.usda")

stage.traverse do |prim|
  puts "#{prim.path} <#{prim.type_name}>"
end

size = stage.prim_at("/World/Cube").attribute("size").get
```

`Stage.open(path, missing_assets: :warn)` warns and skips unresolved sublayers
or references. The default policy, `:error`, raises
`OpenUSD::CompositionError`; `:ignore` silently skips them.

## Time samples and metadata

```ruby
prim = stage.prim_at("/World/Cube")
attribute = prim.create_attribute("animatedSize", "double")
attribute.set(1.0, time: 0)
attribute.set(3.0, time: 24)

attribute.get(time: 12) # => 2.0
prim.metadata["kind"] = "component"
attribute.metadata["documentation"] = "Animated cube size"
```

## Schema helpers

```ruby
xform = OpenUSD::Schema::Xform.define(stage, "/World/Model")
xform.translate = [0, 2, 0]
xform.scale = [2, 2, 2]

mesh = OpenUSD::Schema::Mesh.define(stage, "/World/Model/Mesh")
mesh.points = [[0, 0, 0], [1, 0, 0], [0, 1, 0]]
mesh.face_vertex_counts = [3]
mesh.face_vertex_indices = [0, 1, 2]
```

## USDZ

Package an existing root layer and its assets:

```ruby
OpenUSD::Format::Usdz::Writer.pack(
  "scene.usdz",
  root: "scene.usda",
  assets: ["textures/albedo.png"]
)
```

Every entry is stored without compression and begins at a 64-byte boundary.
The reader validates bounds, CRC values, alignment, encryption/compression
flags, and extraction paths.

```ruby
stage = OpenUSD::Stage.open("scene.usdz")
OpenUSD::Format::Usdz::Reader.unpack("scene.usdz", destination: "unpacked")
```

## Command line

```text
openusd cat scene.usda
openusd cat --output formatted.usda scene.usda
openusd tree scene.usdz
openusd zip scene.usdz scene.usda textures/albedo.png
```

The repository includes a reproducible
[CLI smoke-test procedure](docs/CLI_SMOKE_TEST.md) covering all three
subcommands and official validation of their outputs.

## Supported scope

Version 1.0 supports:

- USDA layer metadata, prims, typed attributes, relationships, time samples,
  dictionaries, connections, references, and variant selections
- deterministic USDA output and semantic round trips
- root layer → authored sublayers → references composition strength
- stored ZIP32 USDZ packages with internal USDA references
- Xform, Mesh, Camera, Material, and Scope conveniences

Version 1.0 does not support USDC (Crate), payloads, inherits, specializes, full
list-edit semantics, Hydra/imaging, or concurrent writes to one Stage. Separate
stages and concurrent read-only access are safe as long as application code
does not mutate their underlying Layers.

Unknown USDA value types and metadata are retained where the parser can
represent their syntax, which allows newer authored data to survive a
parse/write round trip.

## Development

```bash
bundle install
bundle exec rake spec
bundle exec rake lint
bundle exec rake doc
bundle exec rake compatibility # requires usdchecker and usdcat on PATH
bundle exec rake golden:update  # intentionally refresh exact writer baselines
bundle exec rake bench
```

The compatibility task validates generated USDA and USDZ files with the
official `usdchecker`, then parses every golden USDA output with `usdcat`.
In CI, where the `usd-core` wheel does not install those executables, the task
uses the equivalent official `UsdValidation` and `Sdf` Python APIs.
The benchmark defaults to 100,000 generated prims and a 1,000,000-vertex Mesh,
reports elapsed time and resident-memory growth, and enforces a five-second
100,000-Prim budget. Set `PRIMS`, `VERTICES`, or `PRIM_BUDGET` to adjust it.

## License

The gem is available under the [MIT License](LICENSE.txt).

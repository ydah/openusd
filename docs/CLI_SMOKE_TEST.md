# CLI smoke test

Run these commands from the repository root after `bundle install`.

```bash
work_dir="$(mktemp -d)"

bundle exec exe/openusd cat \
  --output "$work_dir/formatted.usda" \
  spec/fixtures/layer_metadata.usda

bundle exec exe/openusd tree spec/fixtures/nested_prims.usda

bundle exec exe/openusd zip \
  "$work_dir/scene.usdz" \
  spec/fixtures/layer_metadata.usda

usdchecker "$work_dir/formatted.usda"
usdchecker "$work_dir/scene.usdz"
```

Expected results:

- `cat` exits successfully and writes a deterministic USDA layer.
- `tree` prints `World`, its `Geometry` child, and the nested `Cube`.
- `zip` exits successfully and creates an uncompressed, aligned USDZ package.
- Both `usdchecker` commands report `Success!`.

The temporary directory can be deleted after inspection.

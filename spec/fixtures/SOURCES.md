# Fixture sources

The `.usda` fixtures directly in this directory were authored specifically for
this project and are distributed under the repository's MIT license. They are
small, independent examples designed to exercise syntax described by the
OpenUSD documentation.

## OpenUSD upstream fixtures

Files below `upstream/` are copies from the official
[PixarAnimationStudios/OpenUSD repository](https://github.com/PixarAnimationStudios/OpenUSD)
at commit `ee47c679abde5b467a7b6a41f3b2285564a4222e`:

| Local file | Upstream path |
|---|---|
| `authoring_properties.usda` | `extras/usd/tutorials/authoringProperties/HelloWorld.usda` |
| `sphere.usda` | `extras/usd/tutorials/convertingLayerFormats/Sphere.usda` |
| `referencing_layers.usda` | `extras/usd/tutorials/referencingLayers/HelloWorld.usda` |
| `traversing_stage.usda` | `extras/usd/tutorials/traversingStage/HelloWorld.usda` |
| `reference_example.usda` | `extras/usd/tutorials/traversingStage/RefExample.usda` |
| `usdcat_payload.usda` | `pxr/usd/bin/usdcat/testenv/testCatToFile/input.usda` |
| `cube_variant.usda` | `pxr/usd/bin/usdcompress/testenv/testCube/Cube.usda` |
| `usdchecker_empty.usda` | `pxr/usdValidation/bin/usdchecker/testenv/testUsdChecker/clean/clean_empty.usda` |
| `usdchecker_material_binding.usda` | `pxr/usdValidation/bin/usdchecker/testenv/testUsdChecker/clean/cleanMaterialBindingAPIApplied.usda` |
| `layer_comment.usda` | `pxr/usd/bin/usdcat/testenv/testUsdCatLayerMetadata/input.usda` |
| `time_samples.usda` | `pxr/usd/bin/usdcompress/testenv/testTimeSample/CubeWithTimeSample.usda` |
| `dancing_cubes.usda` | `extras/usd/examples/usdDancingCubesExample/dancingCubes.usda` |
| `single_usda.usdz.base64` | `pxr/usd/usd/testenv/testUsdUsdzFileFormat/single_usda.usdz` |

These files are covered by the Tomorrow Open Source Technology License 1.0.
The applicable license and notice are included as `upstream/OPENUSD-LICENSE.txt`
and `upstream/OPENUSD-NOTICE.txt`. The binary USDZ is stored as an unmodified
base64 representation so it can be reviewed and reproduced in a text-only
source checkout. Files carrying a `Modified by the openusd Ruby project`
comment differ only in indentation or final-newline normalization.

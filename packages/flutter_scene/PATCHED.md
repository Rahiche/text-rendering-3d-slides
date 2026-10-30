# flutter_scene 0.23.0, patched

A copy of [flutter_scene](https://github.com/bdero/flutter_scene) 0.23.0 (MIT,
see LICENSE), used through a `dependency_overrides` in `booth3d/pubspec.yaml`
until the fix is in a release. Only its web (WebGL2) backend is changed:

- `lib/src/gpu/web/render_pass.dart`, `bindVertexBuffer`: re-binding a slot
  replaces its pending binding instead of appending another. The scene
  encoder re-binds every slot per draw without clearing between the draws of
  one pipeline (as the native backend allows), so the web backend re-applied
  every binding since the last clear on every draw: quadratic in a pipeline's
  run of draws. In Name City that was about 4 million WebGL calls a frame
  (4 fps) and a VAO cache miss on every draw.
- `lib/src/gpu/web/gpu_context.dart`: the VAO cache holds 4096 (was 512), so
  a big scene's frame fits once the keys are stable.

Left out of the copy: example/, screenshots/, test/, skills/, and the build
hook's own output (build/, flutter_scene_generated/'s contents).

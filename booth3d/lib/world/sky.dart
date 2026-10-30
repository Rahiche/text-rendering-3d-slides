import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../tuning.dart';
import 'ease.dart';

/// The sky over the city: a photographed one, Poly Haven's "Kloofendal 38°
/// Partly Cloudy (Pure Sky)" (CC0, assets/sky/CREDITS.md): high cloud over
/// a hazy horizon, a morning sun 38° up. The photograph is the background
/// and the image-based light; its sun, measured and lifted out of it
/// (tool/sky/sky_sun.py), is the directional light that casts the shadows,
/// at the strength it had in the photograph, so sun and shade keep the
/// balance they had that morning. The sky is turned so that the sun stands
/// where the city's always has: behind the camera's right, lighting the
/// plaza, the letters and the people from the side.
class Sky3D {
  Sky3D(this.scene);

  final Scene scene;

  /// 0 = day … 1 = night (windows, lamps, neon): always day, so 0; what
  /// lights up after dark stays off.
  double night = 0;

  /// 0 … 1 around sunrise and sunset (golden light): 0, as [night].
  double twilight = 0;

  /// How far the talk's look is on (0 the booth's … 1 the talk's, set by
  /// the world): crisp (their pick of three, 2026-10-28): clear air, true
  /// colour (a neutral tone curve), deep contact shadows, more of the sky's
  /// light in the shade, glass that reflects, nothing soft (no lens blur:
  /// world.dart).
  double talk = 0;

  /// How far the camera's underground (0 … 1, set by the world): down the
  /// Unicode archive's stair, the air goes dark (no sky to take the colour
  /// of, no sun to scatter), and thicker.
  double underground = 0;

  /// The direction towards the sun.
  final sun = vm.Vector3(0, 1, 0);

  /// The photograph: 4K on the Mac, 2K on the web (a quarter of the
  /// download, and the decode runs on the page's one thread there).
  static const _asset = kIsWeb ? 'assets/sky/sky_2k.hdr' : 'assets/sky/sky_4k.hdr';

  /// Measured in it (sky_sun.py): the sun's direction in the photograph's
  /// own frame, its irradiance (RGB, in the photograph's units), and the
  /// horizon's radiance (the haze's colour). (The photograph's turned
  /// 1934 of its 4096 columns, 170°, by tool/sky/sky_roll.py, and the sun
  /// with it, from (0.63779, 0.61571, 0.46274): where its edges meet,
  /// flutter_scene's skybox draws a hairline, and that's now to the
  /// south-south-east, where the talk's cameras hardly ever look, not due
  /// north.)
  static final _skySun = vm.Vector3(-0.70857, 0.61571, -0.34472);
  static final _sunRgb = vm.Vector3(2.94, 2.776, 2.483);
  static final _horizon = vm.Vector3(0.3995, 0.4293, 0.453);

  /// Where the sun stands over the city, as a compass direction (x, z):
  /// east-south-east, as it did at mid-morning on the old painted sky.
  static const _heading = (0.589, -0.808);

  /// The balance, a little sunnier than the photograph's (its sun was
  /// behind thin cloud: under it, shade was nearly as bright as sun): the
  /// sun [_sunBoost] times as strong, the sky's fill [_fill] of it (the sky
  /// itself shown as bright as ever), about 3 : 1 on the ground. Then the
  /// exposure that brings a sunlit grey ground to a mid grey.
  static const _sunBoost = 1.8, _fill = 0.7, _exposure = 0.85;

  late final DirectionalLight _light;

  /// Capture aid: --dart-define=BOOTH3D_STYLE=golden|soft tries one of the
  /// other looks on the talk (its sun, the sky's light, the grade), to
  /// compare; nothing changes without it.
  static const style = String.fromEnvironment('BOOTH3D_STYLE');

  Future<void> init() async {
    // The sky's sampled at (its transform × the world's direction): turn it
    // so that its sun comes round to [_heading].
    final theta = math.atan2(_skySun.z, _skySun.x) - math.atan2(_heading.$2, _heading.$1);
    await scene.loadEnvironment(_asset, rotationY: -theta, intensity: _fill, exposure: _exposure);
    scene.skybox?.intensity = 1 / _fill;
    sun.setFrom(scene.environmentTransform.transposed().transformed(_skySun));
    final lum = _sunRgb.dot(vm.Vector3(0.2126, 0.7152, 0.0722));
    _light = DirectionalLight(
      direction: -sun,
      color: _sunRgb / lum,
      intensity: lum * _sunBoost,
      castsShadow: true,
      shadowMaxDistance: 80,
      shadowCascadeCount: Tuning.cascades,
      shadowMapResolution: Tuning.shadowRes,
      // Contact-hardening: crisp where things meet the ground, softer the
      // further the shadow falls (the sun's real size), never mushy.
      shadowFilter: DirectionalShadowFilter.pcss,
      angularRadius: 0.0047,
      shadowSoftness: 0.05,
      shadowDepthBias: 0.015,
      shadowNormalBias: 0.02,
    );
    scene.directionalLight = _light;
    switch (style) {
      case 'golden':
        // Late afternoon: the same heading, the sun 15° up, warm; less of
        // the sky's light, so the shade's cooler and deeper.
        const e = 15 * math.pi / 180;
        sun.setValues(math.cos(e) * _heading.$1, math.sin(e), math.cos(e) * _heading.$2);
        _light
          ..direction = -sun
          ..color = vm.Vector3(1.0, 0.7, 0.44)
          ..intensity = lum * _sunBoost * 1.45
          ..shadowSoftness = 0.08;
        scene.environmentIntensity = _fill * 0.72;
      case 'soft':
        // Overcast: the sun behind cloud, the sky's light all round.
        _light
          ..intensity = lum * _sunBoost * 0.4
          ..shadowSoftness = 0.35;
        scene.environmentIntensity = _fill * 1.45;
    }
    // Contact occlusion: feet on the ground, bricks on bricks, kerbs, the
    // stalls' counters: darker where things meet, so nothing floats.
    scene.ambientOcclusion
      ..enabled = Tuning.ao
      ..method = AmbientOcclusionMethod.groundTruth
      ..intensity = 0.9
      ..radius = 0.45
      ..power = 1.5
      ..halfResolution = true;
    _light
      ..contactShadows = Tuning.ao
      ..contactShadowDistance = 0.35;
    // A film's response: highlights roll off without bending their hue.
    scene.toneMapping = ToneMappingMode.agx;
    scene.postProcess.bloom
      ..enabled = true
      ..scatter = 0.7;
    scene.postProcess.colorGrading.enabled = true;
    scene.postProcess.vignette
      ..enabled = true
      ..radius = 0.8
      ..smoothness = 0.55;
    // The air: a height fog in the horizon's colour, taking the sky's own
    // colour where it's looked through, brighter towards the sun.
    scene.fog
      ..enabled = true
      ..mode = FogMode.exponential
      ..color = _horizon
      ..heightFalloff = 0.035
      ..height = 0
      ..skyColorInfluence = 0.85
      ..sunInScatter = 0.3
      ..sunInScatterExponent = 10;
  }

  void update(double t, [double dt = 1 / 60]) {
    final k = talk, g = underground;
    // (The booth's build a miniature's look: bright, its colours strong and
    // warm, and hardly any haze in the air, haze being what makes a place
    // look big. The talk's crisp.)
    scene
      ..toneMapping = k > 0.5 ? ToneMappingMode.pbrNeutral : ToneMappingMode.agx
      ..exposure = _exposure * lerp(1.05, 1.06, k)
      ..environmentIntensity = _fill * lerp(1.0, 1.15, k);
    _light.shadowSoftness = lerp(0.05, 0.02, k);
    scene.fog
      ..density = lerp(lerp(0.0005, 0.0008, k), 0.0035, g)
      ..color.setValues(lerp(_horizon.x, 0.006, g), lerp(_horizon.y, 0.007, g), lerp(_horizon.z, 0.009, g))
      ..heightFalloff = lerp(0.035, 0.0, g)
      ..skyColorInfluence = lerp(0.85, 0.0, g)
      ..sunInScatter = lerp(0.3, 0.0, g);
    scene.postProcess.bloom
      ..threshold = lerp(1.4, 1.8, k)
      ..intensity = lerp(0.07, 0.03, k);
    scene.postProcess.colorGrading
      ..saturation = lerp(1.24, 1.06, k)
      ..contrast = lerp(1.1, 1.08, k)
      ..temperature = lerp(0.05, 0.0, k);
    scene.postProcess.vignette.intensity = lerp(0.3, 0.0, k);
    scene.ambientOcclusion
      ..intensity = lerp(0.9, 1.3, k)
      ..radius = lerp(0.45, 0.6, k);
    scene.screenSpaceReflections
      ..enabled = k > 0.5 && g < 0.5
      ..intensity = 0.5
      ..maxSteps = 48;
    if (style.isNotEmpty && k > 0) _tried(k, g);
  }

  /// The look BOOTH3D_STYLE tries, [k] of the way on (the talk's), [g]
  /// underground.
  void _tried(double k, double g) {
    final fog = scene.fog, grade = scene.postProcess.colorGrading, bloom = scene.postProcess.bloom;
    switch (style) {
      case 'golden':
        // Late afternoon: a warm low sun, long shadows, its light in the
        // air; warm highlights, cool shade.
        scene
          ..toneMapping = ToneMappingMode.aces
          ..exposure = _exposure * 1.3;
        fog
          ..density = lerp(fog.density, lerp(0.0022, 0.0035, g), k)
          ..color.setValues(lerp(0.62, 0.006, g), lerp(0.5, 0.007, g), lerp(0.4, 0.009, g))
          ..sunInScatter = lerp(0.7, 0, g)
          ..sunInScatterExponent = 6;
        bloom
          ..threshold = 1.05
          ..intensity = 0.14;
        grade
          ..saturation = 1.1
          ..contrast = 1.12
          ..temperature = 0.22
          ..tint = 0.02
          ..lift.setValues(0.0, 0.01, 0.025)
          ..gain.setValues(1.04, 0.99, 0.92);
        scene.postProcess.vignette.intensity = 0.38;
      case 'soft':
        // An overcast day: light from everywhere, soft shadows, matte
        // colour, lifted blacks.
        scene
          ..toneMapping = ToneMappingMode.agx
          ..exposure = _exposure * 1.12;
        fog
          ..density = lerp(fog.density, lerp(0.0016, 0.0035, g), k)
          ..color.setValues(lerp(0.72, 0.006, g), lerp(0.75, 0.007, g), lerp(0.78, 0.009, g))
          ..sunInScatter = 0;
        bloom
          ..threshold = 1.5
          ..intensity = 0.05;
        grade
          ..saturation = 0.95
          ..contrast = 0.98
          ..temperature = -0.02
          ..lift.setValues(0.014, 0.015, 0.018);
        scene.postProcess.vignette.intensity = 0.14;
        scene.ambientOcclusion
          ..intensity = 1.35
          ..radius = 0.8;
    }
  }
}

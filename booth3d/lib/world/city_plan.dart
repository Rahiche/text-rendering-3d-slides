/// The city's street plan, shared by the city, its props and its life.
///
/// Metres; x east, y up, z north. The camera is on the −Z side looking
/// north at the plaza, so the avenue runs in front of the plaza and the city
/// rises behind and to the sides of it.
abstract final class Plan {
  /// The front avenue runs along x between these z.
  static const aveZ0 = -19.0, aveZ1 = -11.0;
  static double get aveZ => (aveZ0 + aveZ1) / 2;

  /// Lanes (Japan keeps left): eastbound on the north half, westbound south.
  static const laneEast = -13.0, laneWest = -17.0;

  /// Side streets run along z, centred on x = ±[streetX].
  static const streetX = 22.5, streetHalf = 3.5;

  /// Road surface height (a curb below the sidewalks).
  static const road = -0.06;

  /// The plaza block (with its 2 m sidewalk ring) spans x ∈ ±[blockX],
  /// z ∈ [aveZ1, …); its open build area is x ∈ ±[plazaX], z ∈ [plazaZ0, plazaZ1].
  static const blockX = 19.0;
  static const plazaX = 17.0, plazaZ0 = -9.0, plazaZ1 = 8.0;

  /// The park behind the plaza.
  static const parkZ0 = 8.0, parkZ1 = 64.0;

  /// Crosswalks over the avenue, at the plaza's corners (x centres).
  static const crossX = [-16.5, 16.5];
  static const crossHalf = 1.6;

  /// Sidewalk centre lines.
  static const walkFront = -10.0; // between the avenue and the plaza
  static const walkFar = -20.0; // the camera side of the avenue
  static const walkFlank = 18.0; // x = ±walkFlank, the plaza block's sides
  static const walkBlock = 27.0; // x = ±walkBlock, the outer blocks' fronts

  /// Where people walk (keeping left of these lines, up to 0.35 m) and
  /// where the furniture stands, clear of them.
  static const peopleFront = -10.3, peopleFlank = 18.0;
  static const peopleFar = [-20.6, -20.0];
  static const peopleBlock = [27.1, 27.6];
  static const lampFlank = 18.75, lampFar = aveZ0 - 2.3, bollardZ = aveZ1 + 0.2;

  /// The street trees along the outer blocks' fronts (city_props.dart): at
  /// x = ±[streetTreeX], from z [streetTreeZ0] every [streetTreeStep] m.
  static const streetTreeX = walkBlock - 0.5, streetTreeZ0 = 2.5, streetTreeStep = 13.0, streetTreeZ1 = 88.0;

  /// Whether a street tree's crown reaches over an awning along a facade
  /// from (ax, az) to (bx, bz).
  static bool streetTreeOver(double ax, double az, double bx, double bz) {
    for (final tx in const [-streetTreeX, streetTreeX]) {
      if (((ax + bx) / 2 - tx).abs() > 3.6) continue;
      final lo = (az < bz ? az : bz) - 1.4, hi = (az < bz ? bz : az) + 1.4;
      for (var tz = streetTreeZ0; tz < streetTreeZ1; tz += streetTreeStep) {
        if (tz > lo && tz < hi) return true;
      }
    }
    return false;
  }

  /// The rest of the city behind the outer blocks, out to its edges east
  /// and west (x0, z0, x1, z1): paved, blocks of offices and flats round
  /// courts and lanes (city_towers.dart), not a lawn.
  static const infill = [(63.0, 3.6, 136.0, 118.0), (-136.0, 3.6, -63.0, 118.0)];

  /// Lots the mini world's scenes (vignette.dart) have instead of the
  /// city's own blocks, trees, lamps and benches (x0, z0, x1, z1).
  static const lots = [
    (-41.0, 4.6, -24.0, 17.8), (24.0, 5.6, 41.0, 20.0), // bidi, atlas
    (-15.8, 73.6, -2.2, 84.4), // farm
    (1.5, 69.5, 18.5, 87.0), (24.0, 21.5, 41.0, 37.0), // relay, itemize
    (-14.5, 86.5, 2.5, 99.5), // the seesaw's playground
    (-41.0, 33.0, -24.0, 49.0), // the demos store
    (-46.0, -9.0, -24.0, 4.3), // the Glyph Works' hall (glyph_works.dart)
  ];

  /// The opening in the ground in ICU City where the stair goes down to
  /// the Unicode archive (v_archive.dart, its frame's x 0.5..3.5, z
  /// −4.2..0): x0, z0, x1, z1.
  static const archiveHole = (-282.0, 32.5, -277.8, 35.5);

  /// Whether (x, z) is on one of the [lots] ([margin] metres round it).
  static bool inLot(double x, double z, [double margin = 0]) =>
      lots.any((l) => x > l.$1 - margin && x < l.$3 + margin && z > l.$2 - margin && z < l.$4 + margin);
}

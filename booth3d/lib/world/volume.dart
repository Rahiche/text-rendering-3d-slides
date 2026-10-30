import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// A building the talk's camera keeps out of when it flies: a box, its
/// [middle] and [half] its size, turned [yaw] about the vertical (as trs's
/// rotY turns a frame). A building the camera may be inside (a hall, a
/// store, an open ground floor) has a [door]: a flight leaves it, and comes
/// into it, through that.
class Volume {
  const Volume(this.middle, this.half, {this.yaw = 0, this.door, this.soft = false});

  final vm.Vector3 middle, half;
  final double yaw;
  final Door? door;

  /// A tree's crown, not a building: flown over on the way, but not where
  /// a flight sets off or arrives (the scenes' cameras stand clear of them;
  /// a crown by one would only make the flight drop steeply into it).
  final bool soft;

  /// [p] in the box's own frame (its middle at the origin, unturned).
  vm.Vector3 local(vm.Vector3 p) {
    final dx = p.x - middle.x, dz = p.z - middle.z, c = math.cos(yaw), s = math.sin(yaw);
    return vm.Vector3(dx * c - dz * s, p.y - middle.y, dx * s + dz * c);
  }

  /// Whether [p] is in it ([margin] metres round it, across: not above).
  bool contains(vm.Vector3 p, [double margin = 0]) {
    final l = local(p);
    return l.x.abs() < half.x + margin && l.z.abs() < half.z + margin && l.y.abs() < half.y;
  }

  /// Whether [p] stands over (or under) it, [margin] metres round it.
  bool over(vm.Vector3 p, [double margin = 0]) {
    final l = local(p);
    return l.x.abs() < half.x + margin && l.z.abs() < half.z + margin;
  }

  /// Its top.
  double get top => middle.y + half.y;
}

/// A way into a [Volume]: the opening's middle on the floor ([at]), which
/// way is out (level, of unit length), its half width and its height.
class Door {
  Door(this.at, vm.Vector3 out, this.halfWidth, this.height) : out = (out..y = 0).normalized();

  final vm.Vector3 at, out;
  final double halfWidth, height;

  /// How far [p] is in from the opening (negative: out in front of it).
  double depthOf(vm.Vector3 p) => (at - p).dot(out);

  /// The way through it for a camera at [p] (or going to it): the point
  /// [by] metres out from the opening's middle (in, if negative), at [p]'s
  /// height as far as the opening allows.
  vm.Vector3 through(vm.Vector3 p, double by) {
    final y = p.y.clamp(math.min(1.6, height * 0.5), math.max(height - 0.6, height * 0.5));
    return at + out * by + vm.Vector3(0, y - at.y, 0);
  }
}

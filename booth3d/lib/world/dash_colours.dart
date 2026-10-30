import 'package:flutter/painting.dart' show Color;

/// A Dash's colours (sRGB): its body's, its belly's, its darker parts'
/// (tuft, tail, feet); a glow over all of it (an emissive colour, and how
/// strong); how rough its finish is (hover_dash.dart's, the rooftop's
/// fighters': package_fight.dart).
typedef DashColours = ({Color body, Color belly, Color dark, Color? glow, double glowStrength, double roughness});

// ignore_for_file: avoid_print

/// Not available on the web.
int currentRssMb() => -1;

void perfLine(String line) => print(line);

/// On the web, the page's query: `?BOOTH3D_RATIO=1.4&BOOTH3D_AO=1` tries
/// the render settings (Tuning) without rebuilding.
String? perfEnv(String key) => Uri.base.queryParameters[key];

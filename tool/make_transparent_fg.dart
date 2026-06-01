// One-off: generate a fully transparent 1024x1024 PNG used as the adaptive-icon
// foreground layer. The real artwork (gradient + mark) lives on the background
// layer so the adaptive icon renders full-bleed; the foreground draws nothing.
// Run: dart run tool/make_transparent_fg.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 1024, height: 1024, numChannels: 4);
  // numChannels:4 inits every pixel to rgba(0,0,0,0) — fully transparent.
  File('assets/logo/virdan-icon-transparent-1024.png')
      .writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote assets/logo/virdan-icon-transparent-1024.png');
}

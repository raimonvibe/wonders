// Derives the generated branding inputs from the one source picture.
//
// There is exactly one image to maintain — branding/app-icon.png, the same file
// the website serves as public/icon-512.png. Everything else under branding/ is
// produced by this script, so the app icon and the website's favicon can never
// drift apart.
//
// Run: dart run tool/make_branding.dart
// Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
//
// What it produces, and why each one is needed:
//
//   adaptive-foreground.png  Android adaptive icons are two layers, and the
//                            launcher crops them to whatever mask the device
//                            uses — a circle, a squircle, a teardrop. Only the
//                            middle ~66% is guaranteed to survive. The source
//                            book spans about 76% of its canvas, so handing it
//                            over unchanged gets its edges shaved off on a
//                            circular mask. This rescales it into the safe zone.
//
//                            The canvas is filled with the source's own
//                            background colour rather than left transparent:
//                            that colour is also the background layer, so the
//                            two match exactly and no crop can reveal a seam or
//                            a keying halo around the book's soft shadow.

import 'dart:io';

import 'package:image/image.dart';

/// Two sizes, because the two consumers inset differently and a single file
/// would be wrong for one of them.
///
/// The launcher icon: flutter_launcher_icons wraps the foreground in its own
/// `<inset android:inset="16%">`, shrinking whatever it is given to 68%. The
/// mask then keeps the central 66%. So a mark drawn at 62% here lands at
/// 62 × 0.68 ÷ 0.66 ≈ 64% of the visible icon, which is where a launcher icon
/// wants to sit.
const _iconMarkFraction = 0.62;

/// The Android 12 splash: no extra inset, and the system draws the image in a
/// 240dp circle whose inner 160dp is the safe area. 45% keeps the book inside
/// that with room to spare, so the circle never clips it.
const _splashMarkFraction = 0.45;

const _canvas = 1024;

void main() {
  final sourceFile = File('branding/app-icon.png');
  if (!sourceFile.existsSync()) {
    stderr.writeln('branding/app-icon.png is missing.');
    exit(1);
  }

  final source = decodePng(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('branding/app-icon.png is not a readable PNG.');
    exit(1);
  }

  final background = _backgroundOf(source);
  final hex = '#${_hex(background.r)}${_hex(background.g)}${_hex(background.b)}';
  stdout.writeln('background colour: $hex');

  final bounds = _markBounds(source, background);
  stdout.writeln(
    'mark bounds: ${bounds.width}×${bounds.height} '
    'at ${bounds.x},${bounds.y} of ${source.width}×${source.height}',
  );

  final mark = copyCrop(
    source,
    x: bounds.x,
    y: bounds.y,
    width: bounds.width,
    height: bounds.height,
  );

  _write(
    'branding/adaptive-foreground.png',
    mark,
    background,
    _iconMarkFraction,
  );
  _write(
    'branding/splash-icon.png',
    mark,
    background,
    _splashMarkFraction,
  );

  stdout.writeln(
    '\nPut $hex in pubspec.yaml under flutter_launcher_icons\n'
    'adaptive_icon_background and flutter_native_splash color if it has moved.',
  );
}

/// Centres [mark] on a [_canvas]-square filled with [background], scaled so its
/// longer side is [fraction] of the canvas.
void _write(String path, Image mark, Color background, double fraction) {
  final target = (_canvas * fraction).round();
  // Scale on the longer side so a non-square mark keeps its proportions.
  final scaled = mark.width >= mark.height
      ? copyResize(mark, width: target)
      : copyResize(mark, height: target);

  final canvas = Image(width: _canvas, height: _canvas)..clear(background);
  compositeImage(
    canvas,
    scaled,
    dstX: (_canvas - scaled.width) ~/ 2,
    dstY: (_canvas - scaled.height) ~/ 2,
  );

  File(path).writeAsBytesSync(encodePng(canvas));
  stdout.writeln('wrote $path — mark at ${(fraction * 100).round()}% of $_canvas');
}

/// The source is a mark on a flat ground, so the corner is the ground.
Color _backgroundOf(Image image) => image.getPixel(2, 2);

/// The tightest box around everything that is not the background.
///
/// The tolerance is generous on purpose: the book carries a soft drop shadow
/// that fades into the ground over many pixels, and cutting through it would
/// crop the mark unevenly.
({int x, int y, int width, int height}) _markBounds(
  Image image,
  Color background,
) {
  const tolerance = 12;
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final distance = (pixel.r - background.r).abs() +
          (pixel.g - background.g).abs() +
          (pixel.b - background.b).abs();
      if (distance <= tolerance) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < 0) {
    stderr.writeln('branding/app-icon.png looks like a flat colour.');
    exit(1);
  }

  return (
    x: minX,
    y: minY,
    width: maxX + 1 - minX,
    height: maxY + 1 - minY,
  );
}

String _hex(num channel) =>
    channel.toInt().toRadixString(16).padLeft(2, '0').toUpperCase();

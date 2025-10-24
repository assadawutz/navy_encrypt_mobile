import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

class _IconSpec {
  const _IconSpec({
    required this.size,
    required this.scale,
    required this.filename,
  });

  final int size;
  final int scale;
  final String filename;

  int get dimension => size * scale;
}

Future<void> _ensureDirectoryExists(Directory directory) async {
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
}

img.Image _generateBaseIcon(int dimension) {
  final image = img.Image(width: dimension, height: dimension);
  final startColor = img.ColorInt8.rgb(0, 74, 173);
  final endColor = img.ColorInt8.rgb(0, 122, 255);

  for (var y = 0; y < dimension; y++) {
    final t = y / (dimension - 1);
    final r = (img.getRed(startColor) * (1 - t) + img.getRed(endColor) * t).toInt();
    final g = (img.getGreen(startColor) * (1 - t) + img.getGreen(endColor) * t).toInt();
    final b = (img.getBlue(startColor) * (1 - t) + img.getBlue(endColor) * t).toInt();
    final color = img.ColorInt8.rgb(r, g, b);
    for (var x = 0; x < dimension; x++) {
      image.setPixel(x, y, color);
    }
  }

  final borderColor = img.ColorInt8.rgb(255, 255, 255);
  final borderThickness = (dimension * 0.05).clamp(2, 20).toInt();
  for (var i = 0; i < borderThickness; i++) {
    for (var x = i; x < dimension - i; x++) {
      image.setPixel(x, i, borderColor);
      image.setPixel(x, dimension - 1 - i, borderColor);
    }
    for (var y = i; y < dimension - i; y++) {
      image.setPixel(i, y, borderColor);
      image.setPixel(dimension - 1 - i, y, borderColor);
    }
  }

  return image;
}

img.Image _generateLaunchImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  final backgroundColor = img.ColorInt8.rgb(0, 74, 173);
  img.fill(image, backgroundColor);

  final waveColor = img.ColorInt8.rgb(255, 255, 255);
  final amplitude = height * 0.04;
  final frequency = 2 * math.pi / width * 6;
  for (var x = 0; x < width; x++) {
    final y = (height / 2 + amplitude * math.sin(frequency * x)).toInt();
    final thickness = (height * 0.01).clamp(2, 12).toInt();
    for (var t = -thickness; t <= thickness; t++) {
      final currentY = (y + t).clamp(0, height - 1);
      image.setPixel(x, currentY, waveColor);
    }
  }

  return image;
}

Future<void> _writePng(File file, img.Image image) async {
  final bytes = img.encodePng(image);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> _generateAppIcons() async {
  final iconDir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  await _ensureDirectoryExists(iconDir);

  const specs = <_IconSpec>[
    _IconSpec(size: 20, scale: 1, filename: 'Icon-App-20x20@1x.png'),
    _IconSpec(size: 20, scale: 2, filename: 'Icon-App-20x20@2x.png'),
    _IconSpec(size: 20, scale: 2, filename: 'Icon-App-20x20@2x-1.png'),
    _IconSpec(size: 20, scale: 3, filename: 'Icon-App-20x20@3x.png'),
    _IconSpec(size: 29, scale: 1, filename: 'Icon-App-29x29@1x.png'),
    _IconSpec(size: 29, scale: 2, filename: 'Icon-App-29x29@2x.png'),
    _IconSpec(size: 29, scale: 2, filename: 'Icon-App-29x29@2x-1.png'),
    _IconSpec(size: 29, scale: 3, filename: 'Icon-App-29x29@3x.png'),
    _IconSpec(size: 40, scale: 1, filename: 'Icon-App-40x40@1x.png'),
    _IconSpec(size: 40, scale: 2, filename: 'Icon-App-40x40@2x.png'),
    _IconSpec(size: 40, scale: 2, filename: 'Icon-App-40x40@2x-1.png'),
    _IconSpec(size: 40, scale: 3, filename: 'Icon-App-40x40@3x.png'),
    _IconSpec(size: 60, scale: 2, filename: 'Icon-App-60x60@2x.png'),
    _IconSpec(size: 60, scale: 3, filename: 'Icon-App-60x60@3x.png'),
    _IconSpec(size: 76, scale: 1, filename: 'Icon-App-76x76@1x.png'),
    _IconSpec(size: 76, scale: 2, filename: 'Icon-App-76x76@2x.png'),
    _IconSpec(size: 83, scale: 2, filename: 'Icon-App-83.5x83.5@2x.png'),
    _IconSpec(size: 1024, scale: 1, filename: 'Icon-App-1024x1024@1x.png'),
  ];

  for (final spec in specs) {
    final icon = _generateBaseIcon(spec.dimension);
    final file = File('${iconDir.path}/${spec.filename}');
    await _writePng(file, icon);
  }
}

Future<void> _generateLaunchImages() async {
  final launchDir = Directory('ios/Runner/Assets.xcassets/LaunchImage.imageset');
  await _ensureDirectoryExists(launchDir);

  final launch2x = _generateLaunchImage(750, 1334);
  await _writePng(File('${launchDir.path}/LaunchImage@2x.png'), launch2x);

  final launch3x = _generateLaunchImage(1125, 2436);
  await _writePng(File('${launchDir.path}/LaunchImage@3x.png'), launch3x);
}

Future<void> main(List<String> args) async {
  await _generateAppIcons();
  await _generateLaunchImages();
  stdout.writeln('Generated iOS app icons and launch images.');
}

import 'package:flutter/material.dart' hide Text;

import '../../core/tr_text.dart';

/// Where the TUGHE logo lives (declared in pubspec.yaml under `assets/images/`).
const String kTugheLogoAsset = 'assets/images/logo.png';

/// The TUGHE logo on a rounded white tile (so it stays visible on the blue header,
/// sidebar and login banner in both light and dark mode). If the image cannot be
/// loaded it falls back to a simple "T" mark instead of showing a broken image.
class TugheLogo extends StatelessWidget {
  const TugheLogo({super.key, this.size = 40, this.radius = 10, this.tile = true});

  final double size;
  final double radius;

  /// White rounded tile behind the logo. Turn off to draw the bare image.
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      kTugheLogoAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Center(
        child: Text('T',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.5, color: const Color(0xFF1E3A8A))),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(tile ? size * 0.1 : 0),
      decoration: tile ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)) : null,
      child: image,
    );
  }
}

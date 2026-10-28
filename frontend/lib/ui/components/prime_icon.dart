// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the PrimePlot brand icon SVG sized to [size].
/// Automatically chooses the dark or light variant from the active [Theme],
/// and allows an explicit tint via [color].
class PrimeIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const PrimeIcon({
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath = isDark
        ? 'assets/branding/icon-on-dark.svg'
        : 'assets/branding/icon-on-light.svg';

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}

/// Renders the full PrimePlot logo (icon + text outline in Rajdhani SemiBold).
class PrimeLogo extends StatelessWidget {
  final double? width;
  final double? height;

  const PrimeLogo({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath = isDark
        ? 'assets/branding/logo-on-dark.svg'
        : 'assets/branding/logo-on-light.svg';

    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
    );
  }
}

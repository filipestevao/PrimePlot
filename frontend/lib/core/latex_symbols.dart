// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

// Greek
const _greek = <String, String>{
  r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
  r'\epsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η', r'\theta': 'θ',
  r'\iota': 'ι', r'\kappa': 'κ', r'\lambda': 'λ', r'\mu': 'μ',
  r'\nu': 'ν', r'\xi': 'ξ', r'\omicron': 'ο', r'\pi': 'π',
  r'\rho': 'ρ', r'\sigma': 'σ', r'\tau': 'τ', r'\upsilon': 'υ',
  r'\phi': 'φ', r'\chi': 'χ', r'\psi': 'ψ', r'\omega': 'ω',
  r'\Alpha': 'Α', r'\Beta': 'Β', r'\Gamma': 'Γ', r'\Delta': 'Δ',
  r'\Epsilon': 'Ε', r'\Zeta': 'Ζ', r'\Eta': 'Η', r'\Theta': 'Θ',
  r'\Iota': 'Ι', r'\Kappa': 'Κ', r'\Lambda': 'Λ', r'\Mu': 'Μ',
  r'\Nu': 'Ν', r'\Xi': 'Ξ', r'\Omicron': 'Ο', r'\Pi': 'Π',
  r'\Rho': 'Ρ', r'\Sigma': 'Σ', r'\Tau': 'Τ', r'\Upsilon': 'Υ',
  r'\Phi': 'Φ', r'\Chi': 'Χ', r'\Psi': 'Ψ', r'\Omega': 'Ω',
};

const _arrows = <String, String>{
  r'\rightarrow': '→', r'\leftarrow': '←',
  r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
  r'\Leftrightarrow': '⇔', r'\leftrightarrow': '↔',
  r'\uparrow': '↑', r'\downarrow': '↓',
  r'\Uparrow': '⇑', r'\Downarrow': '⇓',
  r'\mapsto': '↦', r'\nearrow': '↗', r'\searrow': '↘',
  r'\to': '→', r'\gets': '←',
};

const _ops = <String, String>{
  r'\sum': '∑', r'\int': '∫', r'\prod': '∏', r'\partial': '∂',
  r'\nabla': '∇', r'\infty': '∞', r'\emptyset': '∅',
  r'\forall': '∀', r'\exists': '∃',
  r'\degree': '°', r'\hbar': 'ℏ', r'\ell': 'ℓ',
};

const _rels = <String, String>{
  r'\leq': '≤', r'\ge': '≥', r'\approx': '≈', r'\simeq': '≃',
  r'\cong': '≅', r'\equiv': '≡', r'\neq': '≠', r'\ne': '≠',
  r'\propto': '∝', r'\sim': '∼',
  r'\subset': '⊂', r'\supset': '⊃',
  r'\subseteq': '⊆', r'\supseteq': '⊇',
  r'\in': '∈', r'\notin': '∉', r'\ni': '∋',
  r'\perp': '⊥', r'\parallel': '∥',
  r'\ll': '≪', r'\gg': '≫',
};

const _misc = <String, String>{
  r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\cdot': '·', r'\bullet': '•', r'\circ': '∘',
  r'\ast': '*', r'\dagger': '†', r'\ddagger': '‡',
  r'\ldots': '…', r'\cdots': '…',
  r'\therefore': '∴', r'\because': '∵',
  r'\angle': '∠', r'\triangle': '△',
  r'\checkmark': '✓', r'\copyright': '©',
  r'\AA': 'Å', r'\O': 'Ø', r'\o': 'ø',
  r'\S': '§', r'\P': '¶',
  r'\%': '%', r'\_': '_', r'\{': '{', r'\}': '}',
};

final Map<String, String> _subMap = {}
  ..addAll(_greek)
  ..addAll(_arrows)
  ..addAll(_ops)
  ..addAll(_rels)
  ..addAll(_misc);

String substituteSymbols(String text) {
  if (text.isEmpty) return text;
  var result = text;
  for (final e in _subMap.entries) {
    result = result.replaceAll(e.key, e.value);
  }
  return result;
}

bool hasLatex(String text) {
  return text.contains(r'\') || text.contains(r'$');
}

List<InlineSpan> buildLatexSpans(
  String text, {
  TextStyle? style,
  double? mathFontSize,
}) {
  final spans = <InlineSpan>[];
  final segments = _splitDollar(text);
  for (var i = 0; i < segments.length; i++) {
    if (i.isOdd) {
      final tex = segments[i];
      try {
        spans.add(
          WidgetSpan(
            child: Math.tex(
              tex,
              textStyle: TextStyle(
                fontSize: mathFontSize ?? (style?.fontSize ?? 12),
                color: style?.color,
              ),
            ),
          ),
        );
      } catch (_) {
        spans.add(TextSpan(text: r'$' + tex + r'$', style: style));
      }
    } else {
      spans.add(TextSpan(text: substituteSymbols(segments[i]), style: style));
    }
  }
  return spans;
}

List<String> _splitDollar(String text) {
  final result = <String>[];
  var start = 0;
  while (start < text.length) {
    final dollar = text.indexOf(r'$', start);
    if (dollar == -1) {
      result.add(text.substring(start));
      break;
    }
    if (dollar > start) {
      result.add(text.substring(start, dollar));
    }
    final end = text.indexOf(r'$', dollar + 1);
    if (end == -1) {
      result.add(text.substring(dollar));
      break;
    }
    result.add(text.substring(dollar + 1, end));
    start = end + 1;
  }
  return result;
}

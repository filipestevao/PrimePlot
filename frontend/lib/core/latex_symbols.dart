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

// Unicode fallback alphabets for text-only contexts (canvas legend, plain
// labels): subscript/superscript glyphs that exist in common UI fonts.
const _subscriptChars = <String, String>{
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
  '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
  '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
  'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ',
  'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ',
  'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ',
  'v': 'ᵥ', 'x': 'ₓ',
};

const _superscriptChars = <String, String>{
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
  'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
  'f': 'ᶠ', 'g': 'ᵍ', 'h': 'ʰ', 'i': 'ⁱ', 'j': 'ʲ',
  'k': 'ᵏ', 'l': 'ˡ', 'm': 'ᵐ', 'n': 'ⁿ', 'o': 'ᵒ',
  'p': 'ᵖ', 'r': 'ʳ', 's': 'ˢ', 't': 'ᵗ', 'u': 'ᵘ',
  'v': 'ᵛ', 'w': 'ʷ', 'x': 'ˣ', 'y': 'ʸ', 'z': 'ᶻ',
};

class _ScriptMatch {
  final String rendered;
  final int end;
  const _ScriptMatch(this.rendered, this.end);
}

class _MathToken {
  final String tex;
  final int end;
  const _MathToken(this.tex, this.end);
}

String substituteSymbols(String text) {
  if (text.isEmpty) return text;
  final out = StringBuffer();
  var plainStart = 0;
  var i = 0;
  while (i < text.length) {
    final ch = text[i];
    if ((ch == '_' || ch == '^') &&
        !(i > 0 && text[i - 1] == r'\')) {
      final script = _readScript(text, i);
      if (script != null) {
        if (i > plainStart) {
          out.write(_replaceSymbols(text.substring(plainStart, i)));
        }
        out.write(script.rendered);
        i = script.end;
        plainStart = i;
        continue;
      }
    }
    i++;
  }
  if (plainStart < text.length) {
    out.write(_replaceSymbols(text.substring(plainStart)));
  }
  return out.toString();
}

String _replaceSymbols(String text) {
  var result = text;
  for (final e in _subMap.entries) {
    result = result.replaceAll(e.key, e.value);
  }
  return result;
}

_ScriptMatch? _readScript(String text, int start) {
  final table = text[start] == '_' ? _subscriptChars : _superscriptChars;
  var i = start + 1;
  if (i >= text.length) return null;
  String content;
  if (text[i] == '{') {
    final close = _matchingBrace(text, i);
    if (close == -1) return null;
    content = text.substring(i + 1, close);
    i = close + 1;
  } else {
    if (!table.containsKey(text[i])) return null;
    content = text[i];
    i++;
  }
  if (content.isEmpty) return null;
  final replaced = _replaceSymbols(content);
  final out = StringBuffer();
  for (var j = 0; j < replaced.length; j++) {
    final ch = replaced[j];
    out.write(table[ch] ?? ch);
  }
  return _ScriptMatch(out.toString(), i);
}

int _matchingBrace(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    final ch = text[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

bool hasLatex(String text) {
  return text.contains(r'\') ||
      text.contains(r'$') ||
      text.contains('_') ||
      text.contains('^') ||
      text.contains('{') ||
      text.contains('}');
}

List<InlineSpan> buildLatexSpans(
  String text, {
  TextStyle? style,
  double? mathFontSize,
  bool forceLatex = false,
}) {
  final spans = <InlineSpan>[];
  final mathStyle = TextStyle(
    fontSize: mathFontSize ?? (style?.fontSize ?? 12),
    color: style?.color,
  );
  final segments = _splitDollar(text);
  for (var i = 0; i < segments.length; i++) {
    if (i.isOdd) {
      spans.add(
        WidgetSpan(child: Math.tex(segments[i], textStyle: mathStyle)),
      );
    } else {
      final segment = segments[i];
      if (forceLatex || hasLatex(segment)) {
        spans.addAll(_parseMathSpans(segment, style, mathStyle));
      } else {
        spans.add(
          TextSpan(text: substituteSymbols(segment), style: style),
        );
      }
    }
  }
  return spans;
}

/// Splits a plain segment into `TextSpan`s and `Math.tex` spans, keeping the
/// math tokens (`_`, `^`, `{}`, commands) on the widget path for
/// typography-grade rendering.
List<InlineSpan> _parseMathSpans(
  String text,
  TextStyle? style,
  TextStyle mathStyle,
) {
  final spans = <InlineSpan>[];
  final plain = StringBuffer();

  void flushPlain() {
    if (plain.isEmpty) return;
    final rendered = substituteSymbols(plain.toString());
    if (rendered.isNotEmpty) {
      spans.add(TextSpan(text: rendered, style: style));
    }
    plain.clear();
  }

  var i = 0;
  while (i < text.length) {
    final token = _readMathToken(text, i);
    if (token == null) {
      plain.write(text[i]);
      i++;
      continue;
    }
    flushPlain();
    spans.add(
      WidgetSpan(child: Math.tex(token.tex, textStyle: mathStyle)),
    );
    i = token.end;
  }
  flushPlain();
  return spans;
}

_MathToken? _readMathToken(String text, int start) {
  final ch = text[start];
  if (ch == r'\') {
    if (start + 1 >= text.length) return null;
    var i = start + 1;
    if (_isLetter(text[i])) {
      while (i < text.length && _isLetter(text[i])) {
        i++;
      }
    } else {
      i++;
    }
    i = _consumeAttachments(text, i);
    return _MathToken(text.substring(start, i), i);
  }
  if (ch == '_' || ch == '^') {
    final after = _consumeScript(text, start);
    if (after == -1) return null;
    final end = _consumeAttachments(text, after);
    return _MathToken(text.substring(start, end), end);
  }
  if (ch == '{') {
    final close = _matchingBrace(text, start);
    if (close == -1) return null;
    final end = _consumeAttachments(text, close + 1);
    return _MathToken(text.substring(start, end), end);
  }
  return null;
}

/// Consumes trailing arguments/scripts of a math token: `{...}`, `[...]`,
/// `_x` and `^x` (e.g. `\frac{1}{2}`, `\sqrt[3]{x}`, `\alpha_0`, `_2^3`).
int _consumeAttachments(String text, int start) {
  var i = start;
  var progressed = true;
  while (progressed) {
    progressed = false;
    if (i >= text.length) break;
    final ch = text[i];
    if (ch == '{') {
      final close = _matchingBrace(text, i);
      if (close == -1) break;
      i = close + 1;
      progressed = true;
    } else if (ch == '[') {
      final close = text.indexOf(']', i + 1);
      if (close == -1) break;
      i = close + 1;
      progressed = true;
    } else if (ch == '_' || ch == '^') {
      final after = _consumeScript(text, i);
      if (after == -1) break;
      i = after;
      progressed = true;
    }
  }
  return i;
}

int _consumeScript(String text, int start) {
  if (start + 1 >= text.length) return -1;
  final argStart = start + 1;
  final ch = text[argStart];
  if (ch == '{') {
    final close = _matchingBrace(text, argStart);
    return close == -1 ? -1 : close + 1;
  }
  if (ch == r'\') {
    if (argStart + 1 >= text.length) return -1;
    var i = argStart + 1;
    if (_isLetter(text[i])) {
      while (i < text.length && _isLetter(text[i])) {
        i++;
      }
    } else {
      i++;
    }
    return i;
  }
  return argStart + 1;
}

bool _isLetter(String ch) {
  final code = ch.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
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

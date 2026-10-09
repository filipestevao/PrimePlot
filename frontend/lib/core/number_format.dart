// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Locale-aware number formatting. The decimal separator comes from user
//! preferences (`.` or `,`). Parsing accepts both separators everywhere;
//! display follows the setting. NaN handling stays at call sites.

import 'state.dart';

/// Current decimal separator (`.` or `,`).
String get decimalSeparator => ProjectState.instance.decimalSeparator.value;

/// Thousands grouping enabled (`,` for dot-decimals, `.` for comma).
bool get useThousandsSeparator =>
    ProjectState.instance.useThousands.value;

bool _isDigits(String s) =>
    s.isNotEmpty && s.codeUnits.every((c) => c >= 48 && c <= 57);

/// Groups the integer part of an already-formatted number string, then
/// localizes the decimal mark. Accepts dot-decimal input (`-?\d+(\.\d+)?`);
/// exponentials pass through with only the mark localized. Anything
/// unrecognized is returned untouched.
String groupDotted(String dotted) {
  var s = dotted;
  if (s.contains('e') || s.contains('E')) {
    return localizeDecimalString(s);
  }
  final sep = decimalSeparator;
  // Exactly one dot here means the decimal mark (toStringAsFixed output);
  // localize it first so grouping separators can never collide with it.
  if (sep == ',') {
    final first = s.indexOf('.');
    if (first >= 0 && s.indexOf('.', first + 1) < 0) {
      s = s.replaceFirst('.', ',');
    } else if (first >= 0) {
      return dotted;
    }
  }
  if (!useThousandsSeparator) return s;
  final groupSep = sep == ',' ? '.' : ',';
  var neg = false;
  if (s.startsWith('-')) {
    neg = true;
    s = s.substring(1);
  }
  final idx = s.indexOf(sep);
  final intPart = idx < 0 ? s : s.substring(0, idx);
  final fracPart = idx < 0 ? '' : s.substring(idx);
  if (intPart.length <= 3 || !_isDigits(intPart)) {
    return (neg ? '-' : '') + intPart + fracPart;
  }
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(groupSep);
    buf.write(intPart[i]);
  }
  return (neg ? '-' : '') + buf.toString() + fracPart;
}

/// Fixed-precision formatting with the configured separators.
String formatNumber(double value, {int precision = 3}) {
  return groupDotted(value.toStringAsFixed(precision));
}

/// Rewrites a dot-decimal string (adaptive ticks, exponentials) for display.
String localizeDecimalString(String dotted) {
  if (decimalSeparator == ',') return dotted.replaceAll('.', ',');
  return dotted;
}

/// Parses user input under the active locale. Grouping separators are
/// stripped by mode (dot mode drops `,`; comma mode drops `.`), then the
/// decimal mark becomes `.` for parsing. Displayed grouped values therefore
/// always round-trip; hand-typed comma decimals in dot mode parse as
/// thousands-stripped integers (switch mode or type a dot instead).
double? tryParseLocalized(String text) {
  var t = text.trim();
  if (t.isEmpty) return null;
  if (decimalSeparator == ',') {
    t = t.replaceAll('.', '');
    t = t.replaceAll(',', '.');
  } else {
    t = t.replaceAll(',', '');
  }
  return double.tryParse(t);
}

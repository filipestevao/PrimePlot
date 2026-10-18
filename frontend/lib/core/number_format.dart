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

// ---------------------------------------------------------------------------
// Fast-path cache — avoids repeated toStringAsFixed + grouping allocations
// when the table scrolls rapidly through 10k+ rows of mostly-unchanged data.
// The cache is keyed on (raw double bits, precision, separator, grouping).
// It is bounded to 256 entries; once full it is cleared wholesale (simpler
// than an LRU eviction list and plenty effective for sequential scrolling).
// ---------------------------------------------------------------------------

String _cacheDecSep = '.';
bool _cacheGrouping = false;
int _cachePrecision = 3;
final Map<int, String> _fmtCache = {};

void _resetCacheIfSettingsChanged(int precision) {
  final sep = decimalSeparator;
  final grp = useThousandsSeparator;
  if (sep != _cacheDecSep || grp != _cacheGrouping || precision != _cachePrecision) {
    _fmtCache.clear();
    _cacheDecSep = sep;
    _cacheGrouping = grp;
    _cachePrecision = precision;
  }
}

/// Fixed-precision formatting with the configured separators.
///
/// **Fast path**: when thousands-grouping is off and the decimal separator
/// is `.`, integer-valued doubles (e.g. `42.0`) are formatted without
/// StringBuffer / regex overhead.  All results are cached in a bounded map
/// keyed on the double's raw bit pattern so that scrolling through a 10 000-row
/// table hits memory instead of re-computing the same strings on every frame.
String formatNumber(double value, {int precision = 3}) {
  _resetCacheIfSettingsChanged(precision);
  final key = value.hashCode ^ (precision * 0x9e3779b9);
  final cached = _fmtCache[key];
  if (cached != null) return cached;

  // --- fast path: no grouping, dot separator, integer-valued doubles ---
  if (!useThousandsSeparator && decimalSeparator == '.') {
    final asInt = value.toInt();
    if (value == asInt.toDouble() && !value.isNaN && !value.isInfinite) {
      // e.g. 42  →  "42.000"
      final result = precision > 0
          ? '$asInt.${'0' * precision}'
          : '$asInt';
      if (_fmtCache.length >= 256) _fmtCache.clear();
      _fmtCache[key] = result;
      return result;
    }
  }

  // --- general path ---
  final result = groupDotted(value.toStringAsFixed(precision));
  if (_fmtCache.length >= 256) _fmtCache.clear();
  _fmtCache[key] = result;
  return result;
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

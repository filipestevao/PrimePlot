// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Shared keyboard shortcut reference (used by the `?` overlay and the
//! Settings → Keyboard tab so the two can never drift apart).

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// (keys, action) rows in display order.
const shortcutRows = [
  ('Ctrl + N', 'New project'),
  ('Ctrl + O', 'Open project'),
  ('Ctrl + S', 'Save project'),
  ('Ctrl + Shift + S', 'Save project as…'),
  ('Ctrl + E', 'Export figure'),
  ('Ctrl + Shift + E', 'Export data'),
  ('Ctrl + F', 'Search nodes & commands'),
  ('Ctrl + Z', 'Undo'),
  ('Ctrl + Y', 'Redo'),
  ('S', 'Toggle series statistics'),
  ('R', 'Reset view to home ranges'),
  ('Esc', 'Clear selection'),
  ('Ctrl + /  or  ?', 'This shortcut map'),
];

class ShortcutMap extends StatelessWidget {
  const ShortcutMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (keys, action) in shortcutRows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    keys,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: PrimeTheme.primaryAccent,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    action,
                    style: TextStyle(
                      fontSize: 12,
                      color: PrimeTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

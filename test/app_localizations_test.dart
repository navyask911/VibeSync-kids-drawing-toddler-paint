import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_drawing_toddler_paint/l10n/app_localizations.dart';

void main() {
  test('required tool and parent labels exist in every initial locale', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final strings = await AppLocalizations.delegate.load(locale);
      for (final key in <String>[
        'tool_brush',
        'tool_bucket',
        'tool_stamp',
        'color_black',
        'restoring_artwork',
        'bg_change',
        'stamp_house',
        'stamp_flower',
        'stamp_pond',
        'stamp_fish',
        'parent_gate_title',
        'undo',
        'redo',
      ]) {
        expect(strings.translate(key), isNotEmpty, reason: '${locale.languageCode}: $key');
      }
    }
  });

  test('unknown locale and missing key fall back safely', () async {
    final unknown = await AppLocalizations.delegate.load(const Locale('it'));
    expect(unknown.translate('tool_brush'), 'Magic Brush');
    expect(unknown.translate('not_a_real_key'), 'not_a_real_key');
  });
}

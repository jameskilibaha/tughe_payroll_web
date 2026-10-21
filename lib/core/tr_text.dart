import 'package:flutter/material.dart' as m;
import 'package:provider/provider.dart';

import 'i18n.dart';
import 'translations.dart';

/// Drop-in replacement for Flutter's [m.Text] that translates its string to
/// English when the app language is English.
///
/// Screens import this instead of the built-in `Text`:
///
///   import 'package:flutter/material.dart' hide Text;
///   import '../core/tr_text.dart';
///
/// Every existing `Text('Kiswahili...')` then follows the language toggle
/// without touching its call site. Strings missing from the dictionary
/// (`translations.dart`) are shown unchanged.
class Text extends m.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  @override
  m.Widget build(m.BuildContext context) {
    final isEn = context.watch<LocaleProvider>().isEnglish;
    return m.Text(
      isEn ? translateText(data) : data,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

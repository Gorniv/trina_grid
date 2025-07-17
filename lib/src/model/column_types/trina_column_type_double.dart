import 'package:intl/intl.dart' as intl;
import 'package:trina_grid/trina_grid.dart';

class TrinaColumnTypeDouble
    with TrinaColumnTypeDefaultMixin, TrinaColumnTypeWithDoubleFormat
    implements TrinaColumnType, TrinaColumnTypeHasFormat<String> {
  @override
  final dynamic defaultValue;

  final bool negative;

  @override
  final String format;

  @override
  final bool applyFormatOnInit;

  final bool allowFirstDot;

  final String? locale;

  TrinaColumnTypeDouble({
    required this.negative,
    required this.format,
    required this.applyFormatOnInit,
    required this.allowFirstDot,
    required this.locale,
    this.defaultValue,
  })  : numberFormat = intl.NumberFormat(format, locale),
        decimalPoint = _getDecimalPoint(format);

  final intl.NumberFormat numberFormat;

  final int decimalPoint;

  static int _getDecimalPoint(String format) {
    final int dotIndex = format.indexOf('.');

    return dotIndex < 0 ? 0 : format.substring(dotIndex).length - 1;
  }
}

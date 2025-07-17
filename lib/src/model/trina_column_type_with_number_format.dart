import 'package:intl/intl.dart' as intl;
import 'package:trina_grid/src/helper/trina_general_helper.dart';

mixin TrinaColumnTypeWithNumberFormat {
  intl.NumberFormat get numberFormat;

  bool get negative;

  int get decimalPoint;

  bool get allowFirstDot;

  String? get locale;

  dynamic get defaultValue;

  bool isValid(dynamic value) {
    if (!isNumeric(value)) {
      return false;
    }

    if (negative == false && num.parse(value.toString()) < 0) {
      return false;
    }

    return true;
  }

  int compare(dynamic a, dynamic b) {
    return TrinaGeneralHelper.compareWithNull(
      a,
      b,
      () => toNumber(a.toString()).compareTo(toNumber(b.toString())),
    );
  }

  dynamic makeCompareValue(dynamic v) {
    return v.runtimeType != num
        ? num.tryParse(v.toString()) ?? defaultValue
        : v;
  }

  String applyFormat(dynamic value) {
    num number = num.tryParse(
          value.toString().replaceAll(numberFormat.symbols.DECIMAL_SEP, '.'),
        ) ??
        defaultValue;

    if (negative == false && number < 0) {
      number = defaultValue;
    }

    return numberFormat.format(number);
  }

  /// Convert [String] converted to [applyFormat] to [number].
  dynamic toNumber(String formatted) {
    String match = '0-9\\-${numberFormat.symbols.DECIMAL_SEP}';

    if (negative) {
      match += numberFormat.symbols.MINUS_SIGN;
    }

    formatted = formatted
        .replaceAll(RegExp('[^$match]'), '')
        .replaceFirst(numberFormat.symbols.DECIMAL_SEP, '.');

    final num formattedNumber = num.tryParse(formatted) ?? defaultValue;

    return formattedNumber.isFinite ? formattedNumber : defaultValue;
  }

  bool isNumeric(dynamic s) {
    if (s == null) {
      return false;
    }
    return num.tryParse(s.toString()) != null;
  }
}

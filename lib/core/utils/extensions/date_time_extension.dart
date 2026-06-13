import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String toFormatString({String pattern = 'dd/MM/yyyy'}) {
    final formatter = DateFormat(pattern);
    return formatter.format(this);
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

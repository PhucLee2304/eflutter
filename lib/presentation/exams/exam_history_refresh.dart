import 'package:flutter/foundation.dart';

final examHistoryRevision = ValueNotifier<int>(0);

void notifyExamHistoryChanged() {
  examHistoryRevision.value++;
}

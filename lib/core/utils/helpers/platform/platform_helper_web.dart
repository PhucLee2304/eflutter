import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' show window;

void configureUrlStrategy() {
  setUrlStrategy(PathUrlStrategy());
}

void refreshPage() {
  window.location.reload();
}

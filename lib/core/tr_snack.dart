import 'package:get/get.dart';

import 'translations.dart';

/// Same as `Get.snackbar(title, message)` but translated to the current
/// language (see translations.dart).
void trSnack(String title, String message, {Duration? duration}) {
  if (duration == null) {
    // Keep GetX's default auto-dismiss duration (passing null would make the
    // snackbar stay on screen forever).
    Get.snackbar(tr(title), tr(message));
  } else {
    Get.snackbar(tr(title), tr(message), duration: duration);
  }
}

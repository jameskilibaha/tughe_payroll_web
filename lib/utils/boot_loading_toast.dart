import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows a "loading" toast (GetX snackbar with a progress indicator) while
/// [readyFutures] are still in flight, then dismisses it automatically.
///
/// Call this from a screen's `initState` via
/// `WidgetsBinding.instance.addPostFrameCallback` - by then `GetMaterialApp`
/// has already built its `Navigator`/`Overlay`, so `Get.snackbar` is safe to
/// call. Calling it any earlier (e.g. directly from a controller's
/// `onInit`, which runs before `runApp`) would silently fail because there
/// is nowhere yet to show it.
Future<void> showBootLoadingToast({
  required List<Future<void>> readyFutures,
  String loadingMessage = 'Inapakua taarifa kutoka kwenye seva...',
}) async {
  if (readyFutures.isEmpty) return;

  Get.rawSnackbar(
    messageText: Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(loadingMessage, style: const TextStyle(color: Colors.white))),
      ],
    ),
    isDismissible: false,
    duration: const Duration(seconds: 25),
    snackPosition: SnackPosition.TOP,
    backgroundColor: Colors.black87,
  );

  try {
    await Future.wait(readyFutures);
  } finally {
    if (Get.isSnackbarOpen) {
      await Get.closeCurrentSnackbar();
    }
  }
}

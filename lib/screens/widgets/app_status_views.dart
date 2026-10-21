import 'package:flutter/material.dart' hide Text;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../core/tr_text.dart';
import '../../core/theme.dart';

const _brandBlue = Color(0xFF1E3A8A);

/// Real loading indicator shown while a controller's first fetch from the
/// backend is still in flight. Used instead of ever showing dummy/sample
/// data as a stand-in for real data.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.message = 'Inapakua taarifa...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingAnimationWidget.staggeredDotsWave(color: Pal.brandText, size: 44),
            const SizedBox(height: 14),
            Text(message, style: TextStyle(color: Pal.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Shown when a fetch from the backend has genuinely failed and there is
/// no data to display - explicit and honest instead of silently falling
/// back to sample/dummy data.
class AppErrorRetryView extends StatelessWidget {
  const AppErrorRetryView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 34, color: Pal.textMuted),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Pal.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Jaribu Tena', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

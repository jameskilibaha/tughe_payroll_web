import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
            LoadingAnimationWidget.staggeredDotsWave(color: _brandBlue, size: 44),
            const SizedBox(height: 14),
            Text(message, style: const TextStyle(color: Colors.black54, fontSize: 12)),
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
            const Icon(Icons.cloud_off_outlined, size: 34, color: Colors.black38),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Jaribu Tena', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

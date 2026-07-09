import 'package:flutter/material.dart';
import 'package:office_core/office_core.dart';

/// Demonstrates the Notifications subsystem.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permission',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Request notification permission. On iOS/macOS this '
                    'shows the system permission dialog. On Android 13+ it '
                    'requests the runtime notification permission.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: OfficeCore.isInitialized
                        ? () => OfficeCore.notifications?.requestPermission()
                        : null,
                    child: const Text('Request Permission'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FCM Token',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    OfficeCore.isInitialized
                        ? (OfficeCore.notifications?.fcmToken ??
                            'Not available')
                        : 'OfficeCore not initialized',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progress Notification',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Show a progress notification (useful for long-running '
                    'tasks like translation or conversion).',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: OfficeCore.isInitialized
                            ? () => OfficeCore.notifications
                                ?.showProgressNotification(
                                  current: 3,
                                  total: 10,
                                  title: 'Translating PDF',
                                )
                            : null,
                        child: const Text('Show (3/10)'),
                      ),
                      ElevatedButton(
                        onPressed: OfficeCore.isInitialized
                            ? () => OfficeCore.notifications
                                ?.showProgressNotification(
                                  current: 7,
                                  total: 10,
                                  title: 'Translating PDF',
                                )
                            : null,
                        child: const Text('Show (7/10)'),
                      ),
                      ElevatedButton(
                        onPressed: OfficeCore.isInitialized
                            ? () => OfficeCore.notifications
                                ?.cancelProgressNotification()
                            : null,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

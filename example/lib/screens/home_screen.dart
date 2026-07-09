import 'package:flutter/material.dart';
import 'package:office_core/office_core.dart';

import '../main.dart';

/// Home screen showing premium status toggle and a summary of all subsystems.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OfficeCore Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium status toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Premium Status',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: premiumNotifier,
                    builder: (context, isPro, _) {
                      return SwitchListTile(
                        title: Text(isPro ? 'Premium 👑' : 'Free'),
                        subtitle: Text(isPro
                            ? 'Ads hidden, all features unlocked'
                            : 'Ads shown, limits enforced'),
                        value: isPro,
                        onChanged: (v) => examplePremiumProvider.setPro(v),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subsystem status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subsystem Status',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _SubsystemTile(
                    name: 'OfficeCore',
                    status: OfficeCore.isInitialized ? 'Initialized' : 'Not initialized',
                    color: OfficeCore.isInitialized ? Colors.green : Colors.orange,
                  ),
                  const _SubsystemTile(
                    name: 'Remote Config',
                    status: 'See Config tab',
                    color: Colors.blue,
                  ),
                  const _SubsystemTile(
                    name: 'Ads',
                    status: 'See Ads tab',
                    color: Colors.blue,
                  ),
                  const _SubsystemTile(
                    name: 'Trial & Limits',
                    status: 'See Trial tab',
                    color: Colors.blue,
                  ),
                  const _SubsystemTile(
                    name: 'Notifications',
                    status: 'See Push tab',
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quickstart info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Start',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'This example app demonstrates the OfficeCore API. '
                    'To see real ad loading, Remote Config fetching, and '
                    'push notifications, initialize Firebase and call '
                    'OfficeCore.initialize() in main.dart.',
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _SubsystemTile extends StatelessWidget {
  const _SubsystemTile({
    required this.name,
    required this.status,
    required this.color,
  });

  final String name;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(name, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          Text(status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  )),
        ],
      ),
    );
  }
}

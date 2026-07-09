import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:office_core/office_core.dart';

/// Demonstrates the typed Remote Config model.
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Config')),
      body: OfficeCore.isInitialized
          ? _buildConfigView(context)
          : const Center(child: Text('OfficeCore not initialized')),
    );
  }

  Widget _buildConfigView(BuildContext context) {
    final config = OfficeCore.rc.current;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('Ads'),
            subtitle: Text(
              'enabled: ${config.platform.ads.enabled}\n'
              'banner visible: ${config.platform.ads.visibility.banner}\n'
              'banner unit ID: ${config.platform.ads.units.banner.isEmpty ? "(empty)" : config.platform.ads.units.banner}',
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Splash'),
            subtitle: Text(
              'showPaywallAfterSplash: ${config.platform.splash.showPaywallAfterSplash}\n'
              'onboarding trial enabled: ${config.platform.splash.onboarding.subscription.trial.enabled}\n'
              'onboarding trial days: ${config.platform.splash.onboarding.subscription.trial.durationDays}',
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Global Locks'),
            subtitle: Text(
              'lockDownload: ${config.platform.global.lockDownload}\n'
              'lockShare: ${config.platform.global.lockShare}\n'
              'lockCopy: ${config.platform.global.lockCopy}',
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Limits'),
            subtitle: Text(
              'globalConversion: ${config.platform.limits.globalConversion}\n'
              'fileSize.free: ${config.platform.limits.fileSize.free} MB\n'
              'fileSize.premium: ${config.platform.limits.fileSize.premium} MB\n'
              'batch.isLocked: ${config.platform.limits.batch.isLocked}',
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Paywall Plans'),
            subtitle: Text(
              config.platform.paywall.plans.isEmpty
                  ? '(no plans configured)'
                  : config.platform.paywall.plans
                      .map((p) =>
                          '${p.planDuration} (${p.productId}, trial: ${p.hasTrial})')
                      .join('\n'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('AI'),
            subtitle: Text(
              'enabled: ${config.platform.ai.enabled}\n'
              'model: ${config.platform.ai.provider.model}\n'
              'defaultProvider: ${config.platform.ai.defaultProvider}',
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
                Text('Raw JSON',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(config.toJson()),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

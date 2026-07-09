import 'package:flutter/material.dart';
import 'package:office_core/office_core.dart';

import '../main.dart';

/// Demonstrates the Trial & Limits subsystem.
class TrialScreen extends StatelessWidget {
  const TrialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trial & Limits')),
      body: ValueListenableBuilder<bool>(
        valueListenable: premiumNotifier,
        builder: (context, isPro, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Trial Status',
                children: [
                  _InfoRow('Trial enabled',
                      OfficeCore.isInitialized ? '${OfficeCore.trial.isTrialEnabled}' : 'N/A'),
                  _InfoRow('Trial duration',
                      OfficeCore.isInitialized ? '${OfficeCore.trial.trialDurationDays} days' : 'N/A'),
                  _InfoRow('Days remaining',
                      OfficeCore.isInitialized ? '${OfficeCore.trial.trialDaysRemaining}' : 'N/A'),
                  _InfoRow('Trial active',
                      OfficeCore.isInitialized ? '${OfficeCore.trial.isTrialActive}' : 'N/A'),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Limits',
                children: [
                  _InfoRow(
                      'Global conversion limit',
                      OfficeCore.isInitialized
                          ? '${OfficeCore.trial.globalConversionLimit}'
                          : 'N/A'),
                  _InfoRow(
                      'File size limit (MB)',
                      OfficeCore.isInitialized
                          ? '${OfficeCore.trial.fileSizeLimit}'
                          : 'N/A'),
                  _InfoRow(
                      'Batch limit',
                      OfficeCore.isInitialized
                          ? '${OfficeCore.trial.batchLimit}'
                          : 'N/A'),
                  _InfoRow(
                      'Batch locked',
                      OfficeCore.isInitialized
                          ? '${OfficeCore.trial.isBatchLocked}'
                          : 'N/A'),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Feature Locks',
                children: [
                  _LockRow('Download', OfficeCore.isInitialized ? OfficeCore.trial.canDownload : false),
                  _LockRow('Share', OfficeCore.isInitialized ? OfficeCore.trial.canShare : false),
                  _LockRow('Copy', OfficeCore.isInitialized ? OfficeCore.trial.canCopy : false),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Usage Tracking',
                children: [
                  _InfoRow(
                      'Tool1 usage',
                      OfficeCore.isInitialized
                          ? '${OfficeCore.trial.getUsage('tool1')} / ${OfficeCore.trial.toolLimit('tool1')}'
                          : 'N/A'),
                  _InfoRow(
                      'Has remaining quota (tool1)',
                      OfficeCore.isInitialized
                          ? '${OfficeCore.trial.hasRemainingQuota('tool1')}'
                          : 'N/A'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: OfficeCore.isInitialized
                        ? () => OfficeCore.trial.incrementUsage('tool1')
                        : null,
                    child: const Text('Increment tool1 usage'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
        ],
      ),
    );
  }
}

class _LockRow extends StatelessWidget {
  const _LockRow(this.label, this.unlocked);
  final String label;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Icon(
            unlocked ? Icons.lock_open : Icons.lock,
            color: unlocked ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }
}

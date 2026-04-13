import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';

class ManageWorkersScreen extends StatelessWidget {
  const ManageWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final workers = [
      {
        'name': '${l10n.translate('worker')} 1',
        'phone': '0500000001',
        'status': l10n.translate('active'),
      },
      {
        'name': '${l10n.translate('worker')} 2',
        'phone': '0500000002',
        'status': l10n.translate('active'),
      },
      {
        'name': '${l10n.translate('worker')} 3',
        'phone': '0500000003',
        'status': l10n.translate('suspended'),
      },
    ];

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('manage_workers'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.translate('manage_workers_subtitle'),
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: workers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final worker = workers[index];
                    final active = worker['status'] == l10n.translate('active');

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(worker['name']!),
                        subtitle: Text(worker['phone']!),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.green.withOpacity(.15)
                                : Colors.red.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            worker['status']!,
                            style: TextStyle(
                              color: active ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
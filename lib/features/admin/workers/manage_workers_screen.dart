import 'package:flutter/material.dart';

class ManageWorkersScreen extends StatelessWidget {
  const ManageWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workers = const [
      {'name': 'عامل 1', 'phone': '0500000001', 'status': 'نشط'},
      {'name': 'عامل 2', 'phone': '0500000002', 'status': 'نشط'},
      {'name': 'عامل 3', 'phone': '0500000003', 'status': 'موقوف'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العمال'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: workers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final worker = workers[index];
          final active = worker['status'] == 'نشط';

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
    );
  }
}

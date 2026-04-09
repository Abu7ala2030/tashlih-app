import 'package:flutter/material.dart';

import '../models/admin_worker_summary.dart';

class AdminWorkerSummaryTile extends StatelessWidget {
  final AdminWorkerSummary worker;

  const AdminWorkerSummaryTile({
    super.key,
    required this.worker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor:
              worker.isOnline ? Colors.green.withOpacity(.15) : Colors.white10,
          child: Icon(
            worker.role == 'driver' ? Icons.local_shipping : Icons.person,
            color: worker.isOnline ? Colors.green : Colors.white,
          ),
        ),
        title: Text(
          worker.name,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(worker.phone),
              const SizedBox(height: 6),
              Text(
                'الطلبات المكتملة: ${worker.completedOrders}  •  الإيراد: ${worker.totalRevenue.toStringAsFixed(2)} ر.س',
              ),
              if (worker.rating > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('التقييم: ${worker.rating.toStringAsFixed(1)}'),
                ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: worker.isOnline
                ? Colors.green.withOpacity(.12)
                : Colors.white10,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            worker.isOnline ? 'متصل' : 'غير متصل',
            style: TextStyle(
              color: worker.isOnline ? Colors.green : Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
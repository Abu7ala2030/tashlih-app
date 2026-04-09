import 'package:flutter/material.dart';

abstract class AdminRecentRequestViewModel {
  String get id;
  String get partName;
  String get customerName;
  String get city;
  String get status;
  String get workerId;
  String get driverId;
  double get amount;
  DateTime? get createdAt;
}

class AdminRecentRequestTile extends StatelessWidget {
  final AdminRecentRequestViewModel request;
  final VoidCallback? onTap;

  const AdminRecentRequestTile({
    super.key,
    required this.request,
    this.onTap,
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
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        title: Text(
          request.partName,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('العميل: ${request.customerName}'),
              if (request.city.trim().isNotEmpty) Text('المدينة: ${request.city}'),
              Text('القيمة: ${request.amount.toStringAsFixed(2)} ر.س'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChipLabel(
                    label: _statusText(request.status),
                    color: _statusColor(request.status),
                  ),
                  if (request.workerId.trim().isNotEmpty)
                    const _ChipLabel(
                      label: 'تم تعيين عامل',
                      color: Colors.blue,
                    ),
                  if (request.driverId.trim().isNotEmpty)
                    const _ChipLabel(
                      label: 'تم تعيين سائق',
                      color: Colors.teal,
                    ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'newRequest':
        return Colors.orange;
      case 'checkingAvailability':
        return Colors.amber;
      case 'available':
        return Colors.lightGreen;
      case 'assigned':
      case 'accepted':
      case 'shipped':
        return Colors.blue;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.white70;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'newRequest':
        return 'جديد';
      case 'checkingAvailability':
        return 'جاري التحقق';
      case 'available':
        return 'متاح';
      case 'assigned':
        return 'مُعيَّن';
      case 'accepted':
        return 'مقبول';
      case 'shipped':
        return 'مشحون';
      case 'delivered':
        return 'تم التسليم';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status.isEmpty ? 'غير معروف' : status;
    }
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _ChipLabel({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../../admin/requests/admin_request_timeline_screen.dart';
import '../../customer/requests/customer_request_tracking_screen.dart';
import '../../worker/requests/worker_request_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String initialType;

  const NotificationsScreen({
    super.key,
    this.initialType = 'all',
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late String selectedType;
  String selectedSort = 'newest';
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String _groupKeyForNotification(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final requestId = (data['requestId'] ?? '').toString();

    if (requestId.isEmpty) {
      return '${type}_standalone';
    }

    return '${type}_$requestId';
  }

  String _groupedTitle({
    required String type,
    required int count,
    required String originalTitle,
  }) {
    if (count <= 1) return originalTitle;

    switch (type) {
      case 'new_offer':
        return '$count عروض جديدة على نفس الطلب';
      case 'offer_accepted':
        return '$count تحديثات قبول عرض';
      case 'request_shipped':
        return '$count تحديثات شحن';
      case 'request_delivered':
        return '$count تحديثات تسليم';
      default:
        return '$count إشعارات متشابهة';
    }
  }

  String _groupedBody({
    required String type,
    required int count,
    required String originalBody,
  }) {
    if (count <= 1) return originalBody;

    switch (type) {
      case 'new_offer':
        return 'تم استلام $count عروض مرتبطة بنفس الطلب.';
      case 'offer_accepted':
        return 'هناك $count تحديثات تخص قبول العرض لنفس الطلب.';
      case 'request_shipped':
        return 'هناك $count تحديثات تخص شحن نفس الطلب.';
      case 'request_delivered':
        return 'هناك $count تحديثات تخص تسليم نفس الطلب.';
      default:
        return 'هناك $count إشعارات متشابهة مرتبطة بنفس الطلب.';
    }
  }

  List<Map<String, dynamic>> _mergeSimilarNotificationsData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};

    for (final doc in docs) {
      final key = _groupKeyForNotification(doc.data());
      grouped.putIfAbsent(key, () => []).add(doc);
    }

    final List<Map<String, dynamic>> merged = [];

    for (final entry in grouped.entries) {
      final items = entry.value;

      items.sort((a, b) {
        final aTs = a.data()['createdAt'];
        final bTs = b.data()['createdAt'];

        final aDate = aTs is Timestamp
            ? aTs.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = bTs is Timestamp
            ? bTs.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      final latest = items.first;
      final latestData = Map<String, dynamic>.from(latest.data());

      merged.add({
        'doc': latest,
        'data': latestData,
        'count': items.length,
      });
    }

    return merged;
  }

  Future<Map<String, dynamic>?> _loadRequest(String requestId) async {
    if (requestId.trim().isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return data;
  }

  Future<String> _loadCurrentRole(String userId) async {
    if (userId.trim().isEmpty) return 'customer';

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(userId)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final role = (data['role'] ?? 'customer').toString().trim();
      return role.isEmpty ? 'customer' : role;
    } catch (_) {
      return 'customer';
    }
  }

  Future<void> _openRelatedRequest(
    BuildContext context, {
    required String requestId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final request = await _loadRequest(requestId);

    if (request == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر العثور على الطلب المرتبط بهذا الإشعار'),
        ),
      );
      return;
    }

    final role = await _loadCurrentRole(userId);

    if (!context.mounted) return;

    if (role == 'admin') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminRequestTimelineScreen(request: request),
        ),
      );
      return;
    }

    if (role == 'worker') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerRequestDetailsScreen(request: request),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerRequestTrackingScreen(request: request),
      ),
    );
  }

  Future<void> _markAsRead(
    DocumentReference<Map<String, dynamic>> reference,
    BuildContext context,
  ) async {
    try {
      await reference.update({'isRead': true});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعيين الإشعار كمقروء')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث الإشعار: $e')),
      );
    }
  }

  Future<void> _markAllAsRead(String userId, BuildContext context) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد إشعارات غير مقروءة')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديد جميع الإشعارات كمقروءة')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث الإشعارات: $e')),
      );
    }
  }

  Future<void> _markPriorityAsRead(
    List<Map<String, dynamic>> priorityItems,
    BuildContext context,
  ) async {
    try {
      final unreadPriority = priorityItems.where((item) {
        final data = item['data'] as Map<String, dynamic>;
        return (data['isRead'] ?? false) == false;
      }).toList();

      if (unreadPriority.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد إشعارات مهمة غير مقروءة')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final item in unreadPriority) {
        final doc = item['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعيين الإشعارات المهمة كمقروءة')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث الإشعارات المهمة: $e')),
      );
    }
  }

  Future<void> _deleteNotification(
    DocumentReference<Map<String, dynamic>> reference,
    BuildContext context,
  ) async {
    try {
      await reference.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الإشعار')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف الإشعار: $e')),
      );
    }
  }

  Future<void> _deleteAllNotifications(
    String userId,
    BuildContext context,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(userId)
          .collection('notifications')
          .get();

      if (snapshot.docs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد إشعارات للحذف')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف جميع الإشعارات')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف جميع الإشعارات: $e')),
      );
    }
  }

  Future<void> _deletePriorityNotifications(
    List<Map<String, dynamic>> priorityItems,
    BuildContext context,
  ) async {
    try {
      if (priorityItems.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد إشعارات مهمة للحذف')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final item in priorityItems) {
        final doc = item['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الإشعارات المهمة')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف الإشعارات المهمة: $e')),
      );
    }
  }

  Future<void> _openFirstPriorityNotification(
    List<Map<String, dynamic>> priorityItems,
    BuildContext context,
  ) async {
    if (priorityItems.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد إشعارات مهمة')),
      );
      return;
    }

    final first = priorityItems.first;
    final doc = first['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
    final data = first['data'] as Map<String, dynamic>;
    final requestId = (data['requestId'] ?? '').toString();

    if ((data['isRead'] ?? false) == false) {
      await doc.reference.update({'isRead': true});
    }

    await _openRelatedRequest(context, requestId: requestId);
  }

  _NotificationVisual _visualForType(String type) {
    switch (type) {
      case 'new_offer':
        return const _NotificationVisual(
          icon: Icons.local_offer_outlined,
          label: 'عرض جديد',
          color: Colors.orange,
        );
      case 'offer_accepted':
        return const _NotificationVisual(
          icon: Icons.verified_outlined,
          label: 'تم قبول العرض',
          color: Colors.green,
        );
      case 'request_shipped':
        return const _NotificationVisual(
          icon: Icons.local_shipping_outlined,
          label: 'تم الشحن',
          color: Colors.indigo,
        );
      case 'request_delivered':
        return const _NotificationVisual(
          icon: Icons.inventory_2_outlined,
          label: 'تم التسليم',
          color: Colors.teal,
        );
      default:
        return const _NotificationVisual(
          icon: Icons.notifications_none,
          label: 'إشعار',
          color: Colors.blueGrey,
        );
    }
  }

  bool _isPriorityType(String type) {
    return type == 'offer_accepted' ||
        type == 'request_shipped' ||
        type == 'request_delivered';
  }

  bool _matchesFilter(String type) {
    if (selectedType == 'all') return true;
    if (selectedType == 'priority') return _isPriorityType(type);
    return type == selectedType;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (searchQuery.trim().isEmpty) return true;

    final q = searchQuery.trim().toLowerCase();
    final title = (data['title'] ?? '').toString().toLowerCase();
    final body = (data['body'] ?? '').toString().toLowerCase();
    final requestId = (data['requestId'] ?? '').toString().toLowerCase();

    return title.contains(q) || body.contains(q) || requestId.contains(q);
  }

  Future<bool?> _confirmDeleteOne(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الإشعار'),
        content: const Text('هل تريد حذف هذا الإشعار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeleteAll(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف جميع الإشعارات'),
        content: const Text('هل أنت متأكد من حذف جميع الإشعارات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeletePriority(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الإشعارات المهمة'),
        content: const Text('هل تريد حذف جميع الإشعارات المهمة فقط؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return today.difference(target).inDays == 1;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final diff = startOfToday
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    return diff >= 1 && diff <= 7;
  }

  String _formatTimeOnly(DateTime date) {
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$hour:$minute $period';
  }

  String _formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final daysDiff = today.difference(target).inDays;

    const months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    if (_isToday(date)) {
      return 'اليوم ${_formatTimeOnly(date)}';
    }

    if (_isYesterday(date)) {
      return 'أمس ${_formatTimeOnly(date)}';
    }

    if (daysDiff >= 2 && daysDiff <= 6) {
      return 'قبل $daysDiff أيام';
    }

    return '${date.day} ${months[date.month]} ${date.year}، ${_formatTimeOnly(date)}';
  }

  void _sortMergedItems(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final aData = a['data'] as Map<String, dynamic>;
      final bData = b['data'] as Map<String, dynamic>;

      final aPriority = _isPriorityType((aData['type'] ?? '').toString());
      final bPriority = _isPriorityType((bData['type'] ?? '').toString());

      if (selectedSort == 'unread_first') {
        final aRead = (aData['isRead'] ?? false) == true;
        final bRead = (bData['isRead'] ?? false) == true;

        if (aRead != bRead) return aRead ? 1 : -1;
      }

      if (aPriority != bPriority) return aPriority ? -1 : 1;

      final aTs = aData['createdAt'];
      final bTs = bData['createdAt'];

      final aDate = aTs is Timestamp
          ? aTs.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = bTs is Timestamp
          ? bTs.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0);

      return selectedSort == 'oldest'
          ? aDate.compareTo(bDate)
          : bDate.compareTo(aDate);
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupMergedNotifications(
    List<Map<String, dynamic>> items,
  ) {
    final today = <Map<String, dynamic>>[];
    final week = <Map<String, dynamic>>[];
    final older = <Map<String, dynamic>>[];

    for (final item in items) {
      final data = item['data'] as Map<String, dynamic>;
      final ts = data['createdAt'];

      if (ts is! Timestamp) {
        older.add(item);
        continue;
      }

      final date = ts.toDate();

      if (_isToday(date)) {
        today.add(item);
      } else if (_isThisWeek(date)) {
        week.add(item);
      } else {
        older.add(item);
      }
    }

    return {
      'today': today,
      'week': week,
      'older': older,
    };
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildCounterCard({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(height: 6),
            ],
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.red.withOpacity(.35)),
      ),
      child: const Text(
        'مهم',
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildPriorityActionsBar(
    BuildContext context,
    List<Map<String, dynamic>> priorityItems,
  ) {
    if (priorityItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF241C1F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إجراءات الإشعارات المهمة',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildActionButton(
                  text: 'المهم كمقروء',
                  icon: Icons.done_all,
                  onTap: () => _markPriorityAsRead(priorityItems, context),
                ),
                _buildActionButton(
                  text: 'فتح أول مهم',
                  icon: Icons.open_in_new,
                  color: Colors.lightBlueAccent,
                  onTap: () => _openFirstPriorityNotification(priorityItems, context),
                ),
                _buildActionButton(
                  text: 'حذف المهم',
                  icon: Icons.delete_sweep_outlined,
                  color: Colors.redAccent,
                  onTap: () async {
                    final confirmed = await _confirmDeletePriority(context);
                    if (confirmed == true) {
                      await _deletePriorityNotifications(priorityItems, context);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMergedNotificationTile(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final doc = item['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
    final data = item['data'] as Map<String, dynamic>;
    final count = item['count'] as int;

    final isRead = (data['isRead'] ?? false) == true;
    final requestId = (data['requestId'] ?? '').toString();
    final type = (data['type'] ?? '').toString();
    final visual = _visualForType(type);
    final isPriority = _isPriorityType(type);

    final ts = data['createdAt'];
    final timeText =
        ts is Timestamp ? _formatFriendlyDate(ts.toDate()) : 'بدون وقت';

    final borderColor = isRead
        ? (isPriority ? Colors.red.withOpacity(.25) : Colors.white10)
        : (isPriority ? Colors.red.withOpacity(.65) : visual.color.withOpacity(.55));

    final backgroundColor = isPriority
        ? (isRead ? const Color(0xFF21181A) : const Color(0xFF2B2023))
        : (isRead ? const Color(0xFF1A1D21) : const Color(0xFF222833));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isPriority ? 1.4 : 1,
        ),
        boxShadow: isPriority
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: visual.color.withOpacity(.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              visual.icon,
              color: visual.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _groupedTitle(
                          type: type,
                          count: count,
                          originalTitle: (data['title'] ?? 'إشعار').toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isPriority) ...[
                      _buildPriorityBadge(),
                      const SizedBox(width: 6),
                    ],
                    if (count > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'x$count',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: visual.color.withOpacity(.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          visual.label,
                          style: TextStyle(
                            color: visual.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _groupedBody(
                    type: type,
                    count: count,
                    originalBody: (data['body'] ?? '').toString(),
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  timeText,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (requestId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'رقم الطلب: $requestId',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (!isRead)
                      _buildActionButton(
                        text: 'كمقروء',
                        icon: Icons.done,
                        onTap: () => _markAsRead(doc.reference, context),
                      ),
                    if (requestId.isNotEmpty)
                      _buildActionButton(
                        text: 'فتح الطلب',
                        icon: Icons.open_in_new,
                        color: Colors.lightBlueAccent,
                        onTap: () => _openRelatedRequest(
                          context,
                          requestId: requestId,
                        ),
                      ),
                    _buildActionButton(
                      text: 'حذف',
                      icon: Icons.delete_outline,
                      color: Colors.redAccent,
                      onTap: () async {
                        final confirmed = await _confirmDeleteOne(context);
                        if (confirmed == true) {
                          await _deleteNotification(doc.reference, context);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergedSection(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _buildSectionTitle(title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: items
                .map((item) => _buildMergedNotificationTile(context, item))
                .toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الإشعارات',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'تابع آخر التحديثات المرتبطة بطلباتك',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (userId.isNotEmpty)
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'read_all') {
                            await _markAllAsRead(userId, context);
                          } else if (value == 'delete_all') {
                            final confirmed = await _confirmDeleteAll(context);
                            if (confirmed == true) {
                              await _deleteAllNotifications(userId, context);
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'read_all',
                            child: Text('تحديد الكل كمقروء'),
                          ),
                          PopupMenuItem(
                            value: 'delete_all',
                            child: Text('حذف جميع الإشعارات'),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث في الإشعارات أو رقم الطلب',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.close),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1A1D21),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'الكل',
                      selected: selectedType == 'all',
                      onTap: () => setState(() => selectedType = 'all'),
                    ),
                    _FilterChip(
                      label: 'مهم',
                      selected: selectedType == 'priority',
                      onTap: () => setState(() => selectedType = 'priority'),
                    ),
                    _FilterChip(
                      label: 'عرض جديد',
                      selected: selectedType == 'new_offer',
                      onTap: () => setState(() => selectedType = 'new_offer'),
                    ),
                    _FilterChip(
                      label: 'قبول عرض',
                      selected: selectedType == 'offer_accepted',
                      onTap: () => setState(() => selectedType = 'offer_accepted'),
                    ),
                    _FilterChip(
                      label: 'تم الشحن',
                      selected: selectedType == 'request_shipped',
                      onTap: () => setState(() => selectedType = 'request_shipped'),
                    ),
                    _FilterChip(
                      label: 'تم التسليم',
                      selected: selectedType == 'request_delivered',
                      onTap: () => setState(() => selectedType = 'request_delivered'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Text(
                      'الفرز:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedSort,
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('الأحدث أولًا'),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text('الأقدم أولًا'),
                          ),
                          DropdownMenuItem(
                            value: 'unread_first',
                            child: Text('غير المقروء أولًا'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedSort = value;
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1A1D21),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestorePaths.users)
                      .doc(userId)
                      .collection('notifications')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'فشل تحميل الإشعارات: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final allItems = snapshot.data?.docs ?? [];

                    final filteredDocs = allItems.where((doc) {
                      final data = doc.data();
                      final type = (data['type'] ?? '').toString();
                      return _matchesFilter(type) && _matchesSearch(data);
                    }).toList();

                    final mergedItems = _mergeSimilarNotificationsData(filteredDocs);
                    _sortMergedItems(mergedItems);
                    final sortedItems = mergedItems;

                    final priorityItems = sortedItems.where((item) {
                      final data = item['data'] as Map<String, dynamic>;
                      return _isPriorityType((data['type'] ?? '').toString());
                    }).toList();

                    final nonPriorityItems = sortedItems.where((item) {
                      final data = item['data'] as Map<String, dynamic>;
                      return !_isPriorityType((data['type'] ?? '').toString());
                    }).toList();

                    final unreadCount = allItems
                        .where((doc) => (doc.data()['isRead'] ?? false) == false)
                        .length;

                    final todayCount = allItems.where((doc) {
                      final ts = doc.data()['createdAt'];
                      return ts is Timestamp && _isToday(ts.toDate());
                    }).length;

                    final weekCount = allItems.where((doc) {
                      final ts = doc.data()['createdAt'];
                      return ts is Timestamp && _isThisWeek(ts.toDate());
                    }).length;

                    final totalCount = allItems.length;

                    if (sortedItems.isEmpty) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              children: [
                                _buildCounterCard(
                                  label: 'غير المقروء',
                                  value: unreadCount.toString(),
                                  icon: Icons.mark_email_unread_outlined,
                                ),
                                const SizedBox(width: 10),
                                _buildCounterCard(
                                  label: 'اليوم',
                                  value: todayCount.toString(),
                                  icon: Icons.today_outlined,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Row(
                              children: [
                                _buildCounterCard(
                                  label: 'هذا الأسبوع',
                                  value: weekCount.toString(),
                                  icon: Icons.date_range_outlined,
                                ),
                                const SizedBox(width: 10),
                                _buildCounterCard(
                                  label: 'الكل',
                                  value: totalCount.toString(),
                                  icon: Icons.notifications_outlined,
                                ),
                              ],
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'لا توجد نتائج مطابقة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final grouped = _groupMergedNotifications(nonPriorityItems);

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              _buildCounterCard(
                                label: 'غير المقروء',
                                value: unreadCount.toString(),
                                icon: Icons.mark_email_unread_outlined,
                              ),
                              const SizedBox(width: 10),
                              _buildCounterCard(
                                label: 'اليوم',
                                value: todayCount.toString(),
                                icon: Icons.today_outlined,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Row(
                            children: [
                              _buildCounterCard(
                                label: 'هذا الأسبوع',
                                value: weekCount.toString(),
                                icon: Icons.date_range_outlined,
                              ),
                              const SizedBox(width: 10),
                              _buildCounterCard(
                                label: 'الكل',
                                value: totalCount.toString(),
                                icon: Icons.notifications_outlined,
                              ),
                            ],
                          ),
                        ),
                        _buildPriorityActionsBar(context, priorityItems),
                        if (priorityItems.isNotEmpty && selectedType != 'priority')
                          _buildMergedSection(
                            context,
                            'الإشعارات المهمة',
                            priorityItems,
                          ),
                        if (selectedType == 'priority')
                          _buildMergedSection(
                            context,
                            'الإشعارات المهمة',
                            priorityItems,
                          ),
                        if (selectedType != 'priority') ...[
                          _buildMergedSection(context, 'اليوم', grouped['today']!),
                          _buildMergedSection(
                            context,
                            'هذا الأسبوع',
                            grouped['week']!,
                          ),
                          _buildMergedSection(context, 'الأقدم', grouped['older']!),
                        ],
                      ],
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

class _NotificationVisual {
  final IconData icon;
  final String label;
  final Color color;

  const _NotificationVisual({
    required this.icon,
    required this.label,
    required this.color,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.white : Colors.white10,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

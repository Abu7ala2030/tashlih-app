import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/widgets/app_item_card.dart';
import '../../../core/widgets/app_shimmer_loader.dart';
import '../../../core/widgets/empty_state_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_chip_filter.dart';
import '../../../providers/request_provider.dart';
import '../../shared/notifications/notification_bell_button.dart';
import 'customer_request_offers_screen.dart';
import 'customer_request_tracking_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  String selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestProvider>().listenToMyRequests();
    });
  }

  @override
  void dispose() {
    context.read<RequestProvider>().stopListening();
    super.dispose();
  }

  Future<void> _refresh() async {
    context.read<RequestProvider>().listenToMyRequests();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  List<Map<String, dynamic>> _sortRequests(List<Map<String, dynamic>> input) {
    final requests = [...input];

    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    requests.sort((a, b) {
      final aNewOffers = ((a['newOffersCount'] ?? 0) as num).toInt();
      final bNewOffers = ((b['newOffersCount'] ?? 0) as num).toInt();

      final aHasNewOffers = aNewOffers > 0;
      final bHasNewOffers = bNewOffers > 0;

      if (aHasNewOffers != bHasNewOffers) {
        return aHasNewOffers ? -1 : 1;
      }

      if (aHasNewOffers && bHasNewOffers && aNewOffers != bNewOffers) {
        return bNewOffers.compareTo(aNewOffers);
      }

      final aLastOfferAt = readDate(a['lastOfferAt']);
      final bLastOfferAt = readDate(b['lastOfferAt']);

      if (aHasNewOffers && bHasNewOffers && aLastOfferAt != bLastOfferAt) {
        return bLastOfferAt.compareTo(aLastOfferAt);
      }

      final aCreatedAt = readDate(a['createdAt']);
      final bCreatedAt = readDate(b['createdAt']);
      return bCreatedAt.compareTo(aCreatedAt);
    });

    return requests;
  }

  bool _matchesSelectedStatus(Map<String, dynamic> request) {
    if (selectedStatus == 'all') return true;
    if (selectedStatus == 'newOffersOnly') {
      return ((request['newOffersCount'] ?? 0) as num).toInt() > 0;
    }
    return (request['status'] ?? '') == selectedStatus;
  }

  void _openRequest(BuildContext context, Map<String, dynamic> request) {
    final status = (request['status'] ?? '').toString();

    if (status == 'assigned' || status == 'shipped' || status == 'delivered') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerRequestTrackingScreen(request: request),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerRequestOffersScreen(request: request),
      ),
    );
  }

  void _openFirstRequestWithNewOffers(
    BuildContext context,
    List<Map<String, dynamic>> sortedRequests,
  ) {
    final target = sortedRequests.where((request) {
      return ((request['newOffersCount'] ?? 0) as num).toInt() > 0;
    }).toList();

    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد حاليًا أي طلب يحتوي على عروض جديدة'),
        ),
      );
      return;
    }

    _openRequest(context, target.first);
  }

  double _bestOfferValue(Map<String, dynamic> request) {
    final raw = request['bestOfferPrice'];
    if (raw is num) return raw.toDouble();
    return 0;
  }

  void _openHighestOfferRequest(
    BuildContext context,
    List<Map<String, dynamic>> allRequests,
  ) {
    final candidates = allRequests.where((request) {
      return _bestOfferValue(request) > 0;
    }).toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد حاليًا أي طلب يحتوي على أعلى عرض محفوظ'),
        ),
      );
      return;
    }

    candidates.sort((a, b) {
      final priceCompare = _bestOfferValue(b).compareTo(_bestOfferValue(a));
      if (priceCompare != 0) return priceCompare;

      final aNewOffers = ((a['newOffersCount'] ?? 0) as num).toInt();
      final bNewOffers = ((b['newOffersCount'] ?? 0) as num).toInt();
      return bNewOffers.compareTo(aNewOffers);
    });

    _openRequest(context, candidates.first);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final allRequests = _sortRequests(provider.requests);

    final requests = _sortRequests(
      allRequests.where(_matchesSelectedStatus).toList(),
    );

    final newOffersRequestsCount = allRequests.where((r) {
      return ((r['newOffersCount'] ?? 0) as num).toInt() > 0;
    }).length;

    final highestOfferCount = allRequests.where((r) {
      return _bestOfferValue(r) > 0;
    }).length;

    if (provider.isLoading) {
      return const Scaffold(
        body: AppGradientBackground(
          child: SafeArea(child: AppShimmerLoader()),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: AppErrorView(
              message: provider.errorMessage!,
              onRetry: () => context.read<RequestProvider>().listenToMyRequests(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'طلباتي',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'يمكنك الآن فتح أول طلب فيه عروض جديدة أو الانتقال مباشرة إلى أعلى عرض قيمة.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const NotificationBellButton(),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'الكل',
                            value: allRequests.length.toString(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'جديد',
                            value: allRequests
                                .where((r) => (r['status'] ?? '') == 'newRequest')
                                .length
                                .toString(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'عروض جديدة',
                            value: newOffersRequestsCount.toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final created = await Navigator.pushNamed(
                            context,
                            '/part-request',
                          );

                          if (created == true && mounted) {
                            context.read<RequestProvider>().listenToMyRequests();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إنشاء الطلب ويمكنك متابعته هنا'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('طلب جديد'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (newOffersRequestsCount > 0 || highestOfferCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2216),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: .35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedStatus == 'newOffersOnly'
                                    ? 'أنت الآن تعرض الطلبات التي وصلتها عروض جديدة فقط.'
                                    : 'الزران السريعان بالأسفل يساعدانك على فتح أهم الطلبات مباشرة.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: newOffersRequestsCount > 0
                                ? () => _openFirstRequestWithNewOffers(
                                      context,
                                      allRequests,
                                    )
                                : null,
                            icon: const Icon(Icons.flash_on_outlined),
                            label: Text(
                              newOffersRequestsCount > 0
                                  ? 'فتح أول طلب فيه عروض جديدة'
                                  : 'لا توجد طلبات بعروض جديدة',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: highestOfferCount > 0
                                ? () => _openHighestOfferRequest(
                                      context,
                                      allRequests,
                                    )
                                : null,
                            icon: const Icon(Icons.trending_up),
                            label: Text(
                              highestOfferCount > 0
                                  ? 'فتح أعلى عرض قيمة'
                                  : 'لا يوجد عرض محفوظ',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      scrollDirection: Axis.horizontal,
                      children: [
                        StatusChipFilter(
                          label: 'الكل',
                          selected: selectedStatus == 'all',
                          onTap: () => setState(() => selectedStatus = 'all'),
                        ),
                        StatusChipFilter(
                          label: 'عروض جديدة فقط',
                          selected: selectedStatus == 'newOffersOnly',
                          onTap: () =>
                              setState(() => selectedStatus = 'newOffersOnly'),
                        ),
                        StatusChipFilter(
                          label: 'جديد',
                          selected: selectedStatus == 'newRequest',
                          onTap: () =>
                              setState(() => selectedStatus = 'newRequest'),
                        ),
                        StatusChipFilter(
                          label: 'جاري التحقق',
                          selected: selectedStatus == 'checkingAvailability',
                          onTap: () => setState(
                            () => selectedStatus = 'checkingAvailability',
                          ),
                        ),
                        StatusChipFilter(
                          label: 'عروض',
                          selected: selectedStatus == 'available',
                          onTap: () =>
                              setState(() => selectedStatus = 'available'),
                        ),
                        StatusChipFilter(
                          label: 'تم التعيين',
                          selected: selectedStatus == 'assigned',
                          onTap: () =>
                              setState(() => selectedStatus = 'assigned'),
                        ),
                        StatusChipFilter(
                          label: 'تم الشحن',
                          selected: selectedStatus == 'shipped',
                          onTap: () =>
                              setState(() => selectedStatus = 'shipped'),
                        ),
                        StatusChipFilter(
                          label: 'تم التسليم',
                          selected: selectedStatus == 'delivered',
                          onTap: () =>
                              setState(() => selectedStatus = 'delivered'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'الطلبات',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${requests.length} طلب',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (requests.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyStateCard(
                          icon: selectedStatus == 'newOffersOnly'
                              ? Icons.local_offer_outlined
                              : Icons.inventory_2_outlined,
                          title: selectedStatus == 'newOffersOnly'
                              ? 'لا توجد طلبات بعروض جديدة الآن'
                              : 'لا توجد طلبات ضمن هذه الحالة',
                          subtitle: selectedStatus == 'newOffersOnly'
                              ? 'عندما يرسل العامل عرضًا جديدًا سيظهر الطلب هنا مباشرة.'
                              : 'بمجرد إرسال طلب جديد سيظهر هنا مع حالته الحالية.',
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final status = (request['status'] ?? '').toString();
                        final newOffersCount =
                            ((request['newOffersCount'] ?? 0) as num).toInt();

                        return Stack(
                          children: [
                            AppItemCard(
                              title: (request['partName'] ?? '').toString(),
                              subtitle:
                                  '${request['vehicleMake'] ?? ''} ${request['vehicleModel'] ?? ''} ${request['vehicleYear'] ?? ''}\nالمدينة: ${request['city'] ?? '-'}${_extraSubtitle(request)}',
                              imageUrl:
                                  (request['vehicleCoverImage'] ?? '').toString(),
                              statusText: _statusText(status),
                              statusColor: _statusColor(status),
                              onTap: () => _openRequest(context, request),
                            ),
                            if (newOffersCount > 0)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    newOffersCount == 1
                                        ? 'عرض جديد'
                                        : '$newOffersCount عروض جديدة',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            if (_bestOfferValue(request) > 0)
                              Positioned(
                                bottom: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF123B2E),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'أعلى عرض: ${_bestOfferValue(request).toStringAsFixed(0)} ريال',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _extraSubtitle(Map<String, dynamic> request) {
    final status = (request['status'] ?? '').toString();
    if (status == 'assigned' || status == 'shipped' || status == 'delivered') {
      final rawPrice = request['acceptedOfferPrice'] ?? 0;
      final displayPrice = rawPrice.toString();
      return '\nالسعر المختار: $displayPrice ريال';
    }

    final bestOffer = _bestOfferValue(request);
    final newOffersCount = ((request['newOffersCount'] ?? 0) as num).toInt();

    final lines = <String>[];
    if (newOffersCount > 0) {
      lines.add('لديك $newOffersCount عروض جديدة على هذا الطلب');
    }
    if (bestOffer > 0) {
      lines.add('أعلى عرض حالي: ${bestOffer.toStringAsFixed(0)} ريال');
    }

    if (lines.isEmpty) return '';
    return '\n${lines.join(' • ')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'unavailable':
        return Colors.red;
      case 'checkingAvailability':
        return Colors.orange;
      case 'reserved':
        return Colors.purple;
      case 'confirmed':
        return Colors.teal;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.greenAccent;
      case 'assigned':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'newRequest':
        return 'طلب جديد';
      case 'checkingAvailability':
        return 'جاري التحقق';
      case 'available':
        return 'وصلت عروض';
      case 'unavailable':
        return 'غير متوفر';
      case 'reserved':
        return 'محجوز';
      case 'confirmed':
        return 'مؤكد';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      case 'assigned':
        return 'تم اختيار العرض';
      default:
        return 'غير معروف';
    }
  }
}

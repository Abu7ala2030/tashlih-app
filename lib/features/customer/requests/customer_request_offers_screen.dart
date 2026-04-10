import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../providers/request_provider.dart';
import 'customer_request_tracking_screen.dart';

class CustomerRequestOffersScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const CustomerRequestOffersScreen({
    super.key,
    required this.request,
  });

  @override
  State<CustomerRequestOffersScreen> createState() =>
      _CustomerRequestOffersScreenState();
}

class _CustomerRequestOffersScreenState
    extends State<CustomerRequestOffersScreen> {
  bool isSubmitting = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get requestId => (widget.request['id'] ?? '').toString();
  String? get _currentUserId => _auth.currentUser?.uid;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (requestId.isNotEmpty) {
        await context.read<RequestProvider>().markOffersAsSeen(
              requestId: requestId,
            );
      }
    });
  }

  Future<Map<String, dynamic>?> _loadFreshRequest() async {
    if (requestId.isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection(FirestorePaths.requests)
        .doc(requestId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return data;
  }

  Future<void> _acceptOffer({
    required String offerId,
    required String workerId,
  }) async {
    setState(() => isSubmitting = true);
    try {
      await context.read<RequestProvider>().acceptOffer(
            requestId: requestId,
            offerId: offerId,
            workerId: workerId,
          );

      final freshRequest = await _loadFreshRequest();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('offer_accepted_successfully'))),
      );

      if (freshRequest != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerRequestTrackingScreen(
              request: freshRequest,
            ),
          ),
        );
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.translate('accept_offer_failed')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _rejectOffer({
    required String offerId,
  }) async {
    setState(() => isSubmitting = true);
    try {
      await context.read<RequestProvider>().rejectOffer(
            requestId: requestId,
            offerId: offerId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('offer_rejected'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.translate('reject_offer_failed')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<bool> _confirmAcceptBestOffer(
    _OfferViewData bestItem,
    List<_OfferViewData> pendingOffers,
  ) async {
    final workerData = bestItem.workerData;
    final workerName = (workerData['name'] ?? '').toString().trim();
    final scrapyardName =
        (workerData['scrapyardName'] ?? widget.request['scrapyardName'] ?? '')
            .toString()
            .trim();

    final displayWorkerName =
        workerName.isNotEmpty ? workerName : l10n.translate('unknown_worker');
    final displayScrapyardName = scrapyardName.isNotEmpty
        ? scrapyardName
        : l10n.translate('unknown_scrapyard');

    final price = _readDouble(bestItem.offerData['price']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('confirm_accept_best_offer')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.translate('worker_name')}: $displayWorkerName'),
              const SizedBox(height: 8),
              Text('${l10n.translate('scrapyard')}: $displayScrapyardName'),
              const SizedBox(height: 8),
              Text(
                '${l10n.translate('price')}: ${price.toStringAsFixed(0)} ${l10n.translate('sar')}',
              ),
              const SizedBox(height: 12),
              Text(
                _primaryRecommendationReason(bestItem, pendingOffers),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.translate('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.translate('confirm_accept')),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _acceptBestOfferDirectly(
    List<_OfferViewData> pendingOffers,
  ) async {
    if (pendingOffers.isEmpty) return;

    final bestItem = pendingOffers.first;
    final status = (bestItem.offerData['status'] ?? 'pending').toString();

    if (status != 'pending') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('no_offer_available_directly'))),
      );
      return;
    }

    final confirmed = await _confirmAcceptBestOffer(bestItem, pendingOffers);
    if (!confirmed) return;

    await _acceptOffer(
      offerId: bestItem.offerId,
      workerId: bestItem.workerId,
    );
  }

  String _normalizePhoneForDial(String phone) {
    return phone.replaceAll(' ', '').replaceAll('-', '');
  }

  String _normalizePhoneForWhatsApp(String phone) {
    var value = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (value.startsWith('+')) return value.substring(1);
    if (value.startsWith('00')) return value.substring(2);
    if (value.startsWith('0')) return '966${value.substring(1)}';
    if (!value.startsWith('966')) return '966$value';
    return value;
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = _normalizePhoneForDial(phone);
    if (cleanPhone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('unable_open_call'))),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final whatsappPhone = _normalizePhoneForWhatsApp(phone);
    if (whatsappPhone.isEmpty) return;

    final uri = Uri.parse('https://wa.me/$whatsappPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('unable_open_whatsapp'))),
    );
  }

  Future<void> _contactBestByCall(List<_OfferViewData> pendingOffers) async {
    if (pendingOffers.isEmpty) return;
    final phone = (pendingOffers.first.workerData['phone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('best_offer_phone_not_available'))),
      );
      return;
    }

    await _makePhoneCall(phone);
  }

  Future<void> _contactBestByWhatsApp(
    List<_OfferViewData> pendingOffers,
  ) async {
    if (pendingOffers.isEmpty) return;
    final phone = (pendingOffers.first.workerData['phone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('best_offer_whatsapp_not_available')),
        ),
      );
      return;
    }

    await _openWhatsApp(phone);
  }

  Future<void> _copyBestPhone(List<_OfferViewData> pendingOffers) async {
    if (pendingOffers.isEmpty) return;
    final phone = (pendingOffers.first.workerData['phone'] ?? '')
        .toString()
        .trim();

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('best_offer_phone_copy_unavailable'))),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('best_offer_phone_copied'))),
    );
  }

  String _buildBestOfferDetailsText(
    _OfferViewData bestItem,
    List<_OfferViewData> pendingOffers,
  ) {
    final workerData = bestItem.workerData;
    final workerName = (workerData['name'] ?? '').toString().trim();
    final scrapyardName =
        (workerData['scrapyardName'] ?? widget.request['scrapyardName'] ?? '')
            .toString()
            .trim();
    final phone = (workerData['phone'] ?? '').toString().trim();

    final displayWorkerName =
        workerName.isNotEmpty ? workerName : l10n.translate('unknown_worker');
    final displayScrapyardName = scrapyardName.isNotEmpty
        ? scrapyardName
        : l10n.translate('unknown_scrapyard');
    final displayPhone = phone.isNotEmpty ? phone : l10n.translate('not_available');

    final partName = (widget.request['partName'] ?? '').toString();
    final vehicleLine =
        '${widget.request['vehicleMake'] ?? ''} ${widget.request['vehicleModel'] ?? ''} ${widget.request['vehicleYear'] ?? ''}'
            .trim();

    final price = _readDouble(bestItem.offerData['price']).toStringAsFixed(0);
    final reason = _primaryRecommendationReason(bestItem, pendingOffers);

    return '''
${l10n.translate('best_offer_currently')}

${l10n.translate('part_name')}: $partName
${l10n.translate('vehicle')}: $vehicleLine
${l10n.translate('worker_name')}: $displayWorkerName
${l10n.translate('scrapyard')}: $displayScrapyardName
${l10n.translate('phone')}: $displayPhone
${l10n.translate('price')}: $price ${l10n.translate('sar')}
${l10n.translate('recommendation_reason')}: $reason
''';
  }

  Future<void> _copyBestOfferDetails(
    List<_OfferViewData> pendingOffers,
  ) async {
    if (pendingOffers.isEmpty) return;
    final text = _buildBestOfferDetailsText(pendingOffers.first, pendingOffers);

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('best_offer_details_copied'))),
    );
  }

  String _workerPhotoUrl(Map<String, dynamic> data) {
    return (data['photoUrl'] ?? data['imageUrl'] ?? data['profileImageUrl'] ?? '')
        .toString()
        .trim();
  }

  String _scrapyardLogoUrl(Map<String, dynamic> data) {
    return (data['scrapyardLogoUrl'] ??
            data['logoUrl'] ??
            data['scrapyardImageUrl'] ??
            '')
        .toString()
        .trim();
  }

  Widget _networkCircleImage({
    required String imageUrl,
    required double radius,
    required IconData fallbackIcon,
  }) {
    if (imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white10,
        child: Icon(fallbackIcon, color: Colors.white70),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white10,
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  Widget _networkRectImage({
    required String imageUrl,
    required double size,
    required IconData fallbackIcon,
    double radius = 14,
  }) {
    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(fallbackIcon, color: Colors.white70),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(fallbackIcon, color: Colors.white70),
          );
        },
      ),
    );
  }

  Widget _buildRatingStars(double rating, {double size = 16}) {
    final safeRating = rating.clamp(0, 5).toDouble();
    final fullStars = safeRating.floor();
    final hasHalfStar = (safeRating - fullStars) >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < fullStars; i++)
          Icon(Icons.star_rounded, size: size, color: Colors.amber),
        if (hasHalfStar)
          Icon(Icons.star_half_rounded, size: size, color: Colors.amber),
        for (int i = 0; i < emptyStars; i++)
          Icon(Icons.star_border_rounded, size: size, color: Colors.amber),
      ],
    );
  }

  Stream<Set<String>> _favoriteWorkerIdsStream() {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      return Stream.value(<String>{});
    }

    return FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('favoriteWorkers')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<void> _toggleFavoriteWorker(_OfferViewData item) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('login_required_first'))),
      );
      return;
    }

    final workerId = item.workerId.trim();
    if (workerId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('worker_id_not_available'))),
      );
      return;
    }

    final workerData = item.workerData;
    final favoriteRef = FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('favoriteWorkers')
        .doc(workerId);

    final favoriteSnap = await favoriteRef.get();

    if (favoriteSnap.exists) {
      await favoriteRef.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('worker_removed_from_favorites'))),
      );
      return;
    }

    await favoriteRef.set({
      'workerId': workerId,
      'name': (workerData['name'] ?? '').toString(),
      'scrapyardName':
          (workerData['scrapyardName'] ?? widget.request['scrapyardName'] ?? '')
              .toString(),
      'phone': (workerData['phone'] ?? '').toString(),
      'photoUrl': _workerPhotoUrl(workerData),
      'scrapyardLogoUrl': _scrapyardLogoUrl(workerData),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('worker_added_to_favorites'))),
    );
  }

  Future<void> _showWorkerDetailsDialog(
    _OfferViewData item, {
    bool isFavorite = false,
  }) async {
    final workerData = item.workerData;

    final workerName = (workerData['name'] ?? '').toString().trim();
    final scrapyardName =
        (workerData['scrapyardName'] ?? widget.request['scrapyardName'] ?? '')
            .toString()
            .trim();
    final phone = (workerData['phone'] ?? '').toString().trim();
    final rating = _readDouble(workerData['rating']);
    final completedOrders = _readInt(workerData['completedOrders']);
    final isVerified = workerData['isVerified'] == true;
    final joinedAt = workerData['createdAt'];
    final workerPhotoUrl = _workerPhotoUrl(workerData);
    final scrapyardLogoUrl = _scrapyardLogoUrl(workerData);

    final displayWorkerName =
        workerName.isNotEmpty ? workerName : l10n.translate('unknown_worker');
    final displayScrapyardName = scrapyardName.isNotEmpty
        ? scrapyardName
        : l10n.translate('unknown_scrapyard');
    final displayPhone = phone.isNotEmpty ? phone : l10n.translate('not_available');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.translate('worker_details')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _networkCircleImage(
                      imageUrl: workerPhotoUrl,
                      radius: 28,
                      fallbackIcon: Icons.person_outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayWorkerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _networkRectImage(
                      imageUrl: scrapyardLogoUrl,
                      size: 56,
                      fallbackIcon: Icons.storefront_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayScrapyardName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (rating > 0) ...[
                  _buildRatingStars(rating, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    '${rating.toStringAsFixed(1)} ${l10n.translate('out_of_5')}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _DialogInfoRow(
                  label: l10n.translate('worker_name'),
                  value: displayWorkerName,
                ),
                _DialogInfoRow(
                  label: l10n.translate('scrapyard'),
                  value: displayScrapyardName,
                ),
                _DialogInfoRow(
                  label: l10n.translate('phone'),
                  value: displayPhone,
                ),
                _DialogInfoRow(
                  label: l10n.translate('rating'),
                  value: rating > 0
                      ? rating.toStringAsFixed(1)
                      : l10n.translate('new_label'),
                ),
                _DialogInfoRow(
                  label: l10n.translate('completed_orders'),
                  value: completedOrders.toString(),
                ),
                _DialogInfoRow(
                  label: l10n.translate('status'),
                  value: isVerified
                      ? l10n.translate('verified')
                      : l10n.translate('not_verified'),
                ),
                _DialogInfoRow(
                  label: l10n.translate('favorites'),
                  value: isFavorite
                      ? l10n.translate('saved_in_favorites')
                      : l10n.translate('not_saved'),
                ),
                _DialogInfoRow(
                  label: l10n.translate('join_date'),
                  value: _formatJoinedDate(joinedAt),
                  isLast: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _toggleFavoriteWorker(item);
              },
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Colors.redAccent,
              ),
              label: Text(
                isFavorite
                    ? l10n.translate('remove_from_favorites')
                    : l10n.translate('add_to_favorites'),
              ),
            ),
            if (phone.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _makePhoneCall(phone);
                },
                icon: const Icon(Icons.call_outlined),
                label: Text(l10n.translate('call')),
              ),
            if (phone.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _openWhatsApp(phone);
                },
                icon: const Icon(Icons.chat_outlined),
                label: Text(l10n.translate('whatsapp')),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.translate('close')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openBestOfferActionsSheet(
    List<_OfferViewData> pendingOffers, {
    bool isFavorite = false,
  }) async {
    if (pendingOffers.isEmpty) return;

    final bestItem = pendingOffers.first;
    final workerData = bestItem.workerData;
    final workerName = (workerData['name'] ?? '').toString().trim();
    final scrapyardName =
        (workerData['scrapyardName'] ?? widget.request['scrapyardName'] ?? '')
            .toString()
            .trim();
    final phone = (workerData['phone'] ?? '').toString().trim();
    final price = _readDouble(bestItem.offerData['price']).toStringAsFixed(0);

    final displayWorkerName =
        workerName.isNotEmpty ? workerName : l10n.translate('unknown_worker');
    final displayScrapyardName = scrapyardName.isNotEmpty
        ? scrapyardName
        : l10n.translate('unknown_scrapyard');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.translate('best_offer_actions'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$displayWorkerName • $displayScrapyardName • $price ${l10n.translate('sar')}',
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionTile(
                  icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                  title: isFavorite
                      ? l10n.translate('remove_worker_from_favorites')
                      : l10n.translate('add_worker_to_favorites'),
                  subtitle: l10n.translate('save_worker_for_quick_access'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _toggleFavoriteWorker(bestItem);
                  },
                ),
                _ActionTile(
                  icon: Icons.info_outline,
                  title: l10n.translate('show_all_worker_details'),
                  subtitle: l10n.translate('worker_details_summary'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _showWorkerDetailsDialog(
                      bestItem,
                      isFavorite: isFavorite,
                    );
                  },
                ),
                _ActionTile(
                  icon: Icons.check_circle_outline,
                  title: l10n.translate('accept_best_offer_directly'),
                  subtitle: l10n.translate('accept_top_priority_offer_now'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _acceptBestOfferDirectly(pendingOffers);
                  },
                ),
                if (phone.isNotEmpty)
                  _ActionTile(
                    icon: Icons.call_outlined,
                    title: l10n.translate('call_best_offer'),
                    subtitle: phone,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _contactBestByCall(pendingOffers);
                    },
                  ),
                if (phone.isNotEmpty)
                  _ActionTile(
                    icon: Icons.chat_outlined,
                    title: l10n.translate('whatsapp_best_offer'),
                    subtitle: l10n.translate('open_whatsapp_directly'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _contactBestByWhatsApp(pendingOffers);
                    },
                  ),
                if (phone.isNotEmpty)
                  _ActionTile(
                    icon: Icons.copy_outlined,
                    title: l10n.translate('copy_best_offer_phone'),
                    subtitle: l10n.translate('copy_phone_to_clipboard'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _copyBestPhone(pendingOffers);
                    },
                  ),
                _ActionTile(
                  icon: Icons.article_outlined,
                  title: l10n.translate('copy_best_offer_details'),
                  subtitle: l10n.translate('copy_name_price_reason'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _copyBestOfferDetails(pendingOffers);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatJoinedDate(dynamic value) {
    if (value is! Timestamp) return l10n.translate('not_specified');
    final date = value.toDate();
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isPendingOffer(_OfferViewData item) {
    return (item.offerData['status'] ?? 'pending').toString() == 'pending';
  }

  String _primaryRecommendationReason(
    _OfferViewData item,
    List<_OfferViewData> comparableItems,
  ) {
    final status = (item.offerData['status'] ?? 'pending').toString();
    if (status != 'pending') {
      return l10n.translate('offer_not_available_now');
    }

    final itemPrice = _readDouble(item.offerData['price']);
    final maxPrice = comparableItems
        .map((e) => _readDouble(e.offerData['price']))
        .fold<double>(0, (a, b) => a > b ? a : b);

    if (itemPrice == maxPrice && maxPrice > 0) {
      return l10n.translate('recommended_highest_price');
    }

    final itemVerified = item.workerData['isVerified'] == true;
    final anyVerified =
        comparableItems.any((e) => e.workerData['isVerified'] == true);
    if (itemVerified && anyVerified) {
      return l10n.translate('recommended_verified_worker');
    }

    final itemRating = _readDouble(item.workerData['rating']);
    final maxRating = comparableItems
        .map((e) => _readDouble(e.workerData['rating']))
        .fold<double>(0, (a, b) => a > b ? a : b);

    if (itemRating > 0 && itemRating == maxRating) {
      return l10n.translate('recommended_highest_rating');
    }

    final itemCompleted = _readInt(item.workerData['completedOrders']);
    final maxCompleted = comparableItems
        .map((e) => _readInt(e.workerData['completedOrders']))
        .fold<int>(0, (a, b) => a > b ? a : b);

    if (itemCompleted > 0 && itemCompleted == maxCompleted) {
      return l10n.translate('recommended_highest_experience');
    }

    return l10n.translate('recommended_best_available');
  }

  List<String> _recommendationTags(
    _OfferViewData item,
    List<_OfferViewData> comparableItems,
  ) {
    final tags = <String>[];

    final status = (item.offerData['status'] ?? 'pending').toString();
    if (status != 'pending') return [l10n.translate('not_available')];

    final price = _readDouble(item.offerData['price']);
    final rating = _readDouble(item.workerData['rating']);
    final completed = _readInt(item.workerData['completedOrders']);
    final isVerified = item.workerData['isVerified'] == true;

    final maxPrice = comparableItems
        .map((e) => _readDouble(e.offerData['price']))
        .fold<double>(0, (a, b) => a > b ? a : b);

    final maxRating = comparableItems
        .map((e) => _readDouble(e.workerData['rating']))
        .fold<double>(0, (a, b) => a > b ? a : b);

    final maxCompleted = comparableItems
        .map((e) => _readInt(e.workerData['completedOrders']))
        .fold<int>(0, (a, b) => a > b ? a : b);

    if (price > 0 && price == maxPrice) tags.add(l10n.translate('highest_price'));
    if (isVerified) tags.add(l10n.translate('verified'));
    if (rating > 0 && rating == maxRating) tags.add(l10n.translate('highest_rating'));
    if (completed > 0 && completed == maxCompleted) {
      tags.add(l10n.translate('highest_experience'));
    }

    if (tags.isEmpty) tags.add(l10n.translate('best_ranked'));
    return tags.take(3).toList();
  }

  Future<List<_OfferViewData>> _buildSortedOffers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offerDocs,
  ) async {
    final workerIds = offerDocs
        .map((doc) => (doc.data()['workerId'] ?? '').toString())
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> workersMap = {};

    await Future.wait(
      workerIds.map((workerId) async {
        try {
          final snap = await FirebaseFirestore.instance
              .collection(FirestorePaths.users)
              .doc(workerId)
              .get();

          workersMap[workerId] = snap.data() ?? <String, dynamic>{};
        } catch (_) {
          workersMap[workerId] = <String, dynamic>{};
        }
      }),
    );

    final items = offerDocs.map((doc) {
      final offer = doc.data();
      final workerId = (offer['workerId'] ?? '').toString();
      final workerData = workersMap[workerId] ?? <String, dynamic>{};

      return _OfferViewData(
        offerId: doc.id,
        offerData: offer,
        workerId: workerId,
        workerData: workerData,
      );
    }).toList();

    items.sort((a, b) {
      final aStatus = (a.offerData['status'] ?? 'pending').toString();
      final bStatus = (b.offerData['status'] ?? 'pending').toString();

      final aPending = aStatus == 'pending';
      final bPending = bStatus == 'pending';
      if (aPending != bPending) return aPending ? -1 : 1;

      final aPrice = _readDouble(a.offerData['price']);
      final bPrice = _readDouble(b.offerData['price']);
      final priceCompare = bPrice.compareTo(aPrice);
      if (priceCompare != 0) return priceCompare;

      final aVerified = a.workerData['isVerified'] == true;
      final bVerified = b.workerData['isVerified'] == true;
      if (aVerified != bVerified) return aVerified ? -1 : 1;

      final aRating = _readDouble(a.workerData['rating']);
      final bRating = _readDouble(b.workerData['rating']);
      final ratingCompare = bRating.compareTo(aRating);
      if (ratingCompare != 0) return ratingCompare;

      final aCompleted = _readInt(a.workerData['completedOrders']);
      final bCompleted = _readInt(b.workerData['completedOrders']);
      final completedCompare = bCompleted.compareTo(aCompleted);
      if (completedCompare != 0) return completedCompare;

      final aDate = _readDate(a.offerData['createdAt']);
      final bDate = _readDate(b.offerData['createdAt']);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final partName = (widget.request['partName'] ?? '').toString();
    final vehicleLine =
        '${widget.request['vehicleMake'] ?? ''} ${widget.request['vehicleModel'] ?? ''} ${widget.request['vehicleYear'] ?? ''}';

    return StreamBuilder<Set<String>>(
      stream: _favoriteWorkerIdsStream(),
      builder: (context, favoriteSnapshot) {
        final favoriteIds = favoriteSnapshot.data ?? <String>{};

        return Stack(
          children: [
            Scaffold(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translate('received_offers'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$partName • $vehicleLine',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection(FirestorePaths.requests)
                              .doc(requestId)
                              .snapshots(),
                          builder: (context, requestSnapshot) {
                            final request = {
                              ...widget.request,
                              ...?requestSnapshot.data?.data(),
                              'id': requestId,
                            };

                            final deliveryAddress =
                                (request['deliveryAddress'] ?? '').toString().trim();
                            final deliveryLat = _readDouble(request['deliveryLat']);
                            final deliveryLng = _readDouble(request['deliveryLng']);
                            final scrapyardName = (request['scrapyardName'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty
                                ? (request['scrapyardName'] ?? '').toString()
                                : l10n.translate('not_specified');
                            final city = (request['city'] ?? '-').toString();

                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection(FirestorePaths.requests)
                                  .doc(requestId)
                                  .collection('offers')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        '${l10n.translate('load_offers_failed')}: ${snapshot.error}',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }

                                final offers = snapshot.data?.docs ?? [];

                                return FutureBuilder<List<_OfferViewData>>(
                                  future: _buildSortedOffers(offers),
                                  builder: (context, sortedSnapshot) {
                                    if (sortedSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    if (sortedSnapshot.hasError) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Text(
                                            '${l10n.translate('prepare_offers_failed')}: ${sortedSnapshot.error}',
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }

                                    final sortedOffers = sortedSnapshot.data ?? [];
                                    final pendingOffers =
                                        sortedOffers.where(_isPendingOffer).toList();

                                    final bestPendingOffer = pendingOffers.isNotEmpty
                                        ? pendingOffers.first
                                        : null;

                                    return Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            0,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(.05),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(.08),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.translate('request_details'),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                _InfoRow(
                                                  label: l10n.translate('part_name'),
                                                  value:
                                                      partName.isEmpty ? '-' : partName,
                                                ),
                                                _InfoRow(
                                                  label: l10n.translate('vehicle'),
                                                  value: vehicleLine.trim().isEmpty
                                                      ? '-'
                                                      : vehicleLine.trim(),
                                                ),
                                                _InfoRow(
                                                  label: l10n.translate('city'),
                                                  value: city,
                                                ),
                                                _InfoRow(
                                                  label: l10n.translate('scrapyard'),
                                                  value: scrapyardName,
                                                ),
                                                _InfoRow(
                                                  label: l10n.translate('delivery_address'),
                                                  value: deliveryAddress.isEmpty
                                                      ? l10n.translate(
                                                          'delivery_address_not_set',
                                                        )
                                                      : deliveryAddress,
                                                  isLast:
                                                      deliveryLat == 0 && deliveryLng == 0,
                                                ),
                                                if (deliveryLat > 0 && deliveryLng > 0)
                                                  _InfoRow(
                                                    label: l10n.translate('coordinates'),
                                                    value:
                                                        '${deliveryLat.toStringAsFixed(6)}, ${deliveryLng.toStringAsFixed(6)}',
                                                    isLast: true,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (bestPendingOffer != null)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              12,
                                              16,
                                              0,
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(.10),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: Colors.green.withOpacity(.25),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    l10n.translate('quick_action'),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _primaryRecommendationReason(
                                                      bestPendingOffer,
                                                      pendingOffers,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: FilledButton.icon(
                                                      onPressed: isSubmitting
                                                          ? null
                                                          : () => _openBestOfferActionsSheet(
                                                                pendingOffers,
                                                                isFavorite:
                                                                    favoriteIds.contains(
                                                                  bestPendingOffer
                                                                      .workerId,
                                                                ),
                                                              ),
                                                      icon: const Icon(
                                                        Icons.bolt_outlined,
                                                      ),
                                                      label: Text(
                                                        l10n.translate(
                                                          'open_best_offer_actions',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          child: offers.isEmpty
                                              ? Center(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(24),
                                                    child: Text(
                                                      l10n.translate(
                                                        'no_offers_yet_for_request',
                                                      ),
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : ListView.separated(
                                                  padding: const EdgeInsets.fromLTRB(
                                                    16,
                                                    16,
                                                    16,
                                                    120,
                                                  ),
                                                  itemCount: sortedOffers.length,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(height: 12),
                                                  itemBuilder: (context, index) {
                                                    final item = sortedOffers[index];
                                                    final data = item.offerData;
                                                    final workerData = item.workerData;

                                                    final workerId = item.workerId;
                                                    final status =
                                                        (data['status'] ?? 'pending')
                                                            .toString();

                                                    final price =
                                                        _readDouble(data['price']);
                                                    final workerName =
                                                        (workerData['name'] ?? '')
                                                            .toString()
                                                            .trim();
                                                    final scrapyardName =
                                                        (workerData['scrapyardName'] ??
                                                                request[
                                                                    'scrapyardName'] ??
                                                                '')
                                                            .toString()
                                                            .trim();
                                                    final workerPhone =
                                                        (workerData['phone'] ?? '')
                                                            .toString()
                                                            .trim();
                                                    final rating = _readDouble(
                                                      workerData['rating'],
                                                    );
                                                    final completedOrders = _readInt(
                                                      workerData['completedOrders'],
                                                    );
                                                    final isVerified =
                                                        workerData['isVerified'] ==
                                                            true;
                                                    final joinedAt =
                                                        workerData['createdAt'];
                                                    final workerPhotoUrl =
                                                        _workerPhotoUrl(workerData);
                                                    final scrapyardLogoUrl =
                                                        _scrapyardLogoUrl(workerData);

                                                    final displayWorkerName =
                                                        workerName.isNotEmpty
                                                            ? workerName
                                                            : l10n.translate(
                                                                'unknown_worker',
                                                              );
                                                    final displayScrapyardName =
                                                        scrapyardName.isNotEmpty
                                                            ? scrapyardName
                                                            : l10n.translate(
                                                                'unknown_scrapyard',
                                                              );
                                                    final displayWorkerPhone =
                                                        workerPhone.isNotEmpty
                                                            ? workerPhone
                                                            : l10n.translate(
                                                                'not_available',
                                                              );

                                                    final isBestPending =
                                                        bestPendingOffer != null &&
                                                            item.offerId ==
                                                                bestPendingOffer.offerId;
                                                    final isFavorite = favoriteIds
                                                        .contains(workerId);

                                                    return Container(
                                                      padding: const EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF1A1D21),
                                                        borderRadius:
                                                            BorderRadius.circular(20),
                                                        border: Border.all(
                                                          color: Colors.white10,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              _networkCircleImage(
                                                                imageUrl: workerPhotoUrl,
                                                                radius: 24,
                                                                fallbackIcon: Icons
                                                                    .person_outline,
                                                              ),
                                                              const SizedBox(width: 10),
                                                              _networkRectImage(
                                                                imageUrl:
                                                                    scrapyardLogoUrl,
                                                                size: 48,
                                                                fallbackIcon: Icons
                                                                    .storefront_outlined,
                                                                radius: 12,
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Expanded(
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        l10n.translate(
                                                                          'price_offer',
                                                                        ),
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize: 18,
                                                                          fontWeight:
                                                                              FontWeight.w900,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    if (isBestPending)
                                                                      Container(
                                                                        padding:
                                                                            const EdgeInsets.symmetric(
                                                                          horizontal: 10,
                                                                          vertical: 5,
                                                                        ),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color: Colors
                                                                              .amber
                                                                              .withOpacity(.18),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                            999,
                                                                          ),
                                                                        ),
                                                                        child: Text(
                                                                          l10n.translate(
                                                                            'best_currently',
                                                                          ),
                                                                          style:
                                                                              const TextStyle(
                                                                            color: Colors
                                                                                .amber,
                                                                            fontWeight:
                                                                                FontWeight.w900,
                                                                            fontSize: 11,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                              IconButton(
                                                                onPressed: () =>
                                                                    _toggleFavoriteWorker(
                                                                  item,
                                                                ),
                                                                icon: Icon(
                                                                  isFavorite
                                                                      ? Icons.favorite
                                                                      : Icons
                                                                          .favorite_border,
                                                                  color: Colors.redAccent,
                                                                ),
                                                                tooltip: isFavorite
                                                                    ? l10n.translate(
                                                                        'remove_from_favorites',
                                                                      )
                                                                    : l10n.translate(
                                                                        'add_to_favorites',
                                                                      ),
                                                              ),
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                  horizontal: 10,
                                                                  vertical: 5,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: _statusColor(
                                                                    status,
                                                                  ).withOpacity(.18),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                    999,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  _statusText(
                                                                    status,
                                                                  ),
                                                                  style: TextStyle(
                                                                    color: _statusColor(
                                                                      status,
                                                                    ),
                                                                    fontWeight:
                                                                        FontWeight.w800,
                                                                    fontSize: 11,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 12),
                                                          _InfoRow(
                                                            label: l10n.translate('price'),
                                                            value:
                                                                '${price.toStringAsFixed(0)} ${l10n.translate('sar')}',
                                                          ),
                                                          _InfoRow(
                                                            label: l10n.translate(
                                                              'worker_name',
                                                            ),
                                                            value: displayWorkerName,
                                                          ),
                                                          _InfoRow(
                                                            label: l10n.translate(
                                                              'scrapyard',
                                                            ),
                                                            value:
                                                                displayScrapyardName,
                                                          ),
                                                          _InfoRow(
                                                            label:
                                                                l10n.translate('phone'),
                                                            value: displayWorkerPhone,
                                                          ),
                                                          _InfoRow(
                                                            label: l10n.translate(
                                                              'offer_time',
                                                            ),
                                                            value: data['createdAt']
                                                                    is Timestamp
                                                                ? (data['createdAt']
                                                                        as Timestamp)
                                                                    .toDate()
                                                                    .toString()
                                                                : '-',
                                                            isLast: true,
                                                          ),
                                                          if (isBestPending) ...[
                                                            const SizedBox(height: 14),
                                                            Container(
                                                              width:
                                                                  double.infinity,
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(14),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors.amber
                                                                    .withOpacity(.08),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                  16,
                                                                ),
                                                                border: Border.all(
                                                                  color: Colors.amber
                                                                      .withOpacity(.22),
                                                                ),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    _primaryRecommendationReason(
                                                                      item,
                                                                      pendingOffers,
                                                                    ),
                                                                    style:
                                                                        const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                      fontSize: 14,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 10,
                                                                  ),
                                                                  Wrap(
                                                                    spacing: 8,
                                                                    runSpacing: 8,
                                                                    children:
                                                                        _recommendationTags(
                                                                      item,
                                                                      pendingOffers,
                                                                    ).map((tag) {
                                                                      return Container(
                                                                        padding:
                                                                            const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              10,
                                                                          vertical: 6,
                                                                        ),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color: Colors
                                                                              .white
                                                                              .withOpacity(.06),
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                            999,
                                                                          ),
                                                                          border:
                                                                              Border.all(
                                                                            color: Colors
                                                                                .white
                                                                                .withOpacity(.08),
                                                                          ),
                                                                        ),
                                                                        child: Text(
                                                                          tag,
                                                                          style:
                                                                              const TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            fontWeight:
                                                                                FontWeight.w800,
                                                                            color:
                                                                                Colors.white,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }).toList(),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                          const SizedBox(height: 14),
                                                          Container(
                                                            width: double.infinity,
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(14),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.white
                                                                  .withOpacity(.05),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                16,
                                                              ),
                                                              border: Border.all(
                                                                color: Colors.white
                                                                    .withOpacity(.08),
                                                              ),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .verified_user_outlined,
                                                                      size: 18,
                                                                      color: Colors
                                                                          .amber,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        l10n.translate(
                                                                          'worker_trust_card',
                                                                        ),
                                                                        style:
                                                                            const TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.w900,
                                                                          fontSize: 15,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      padding:
                                                                          const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical: 6,
                                                                      ),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: isVerified
                                                                            ? Colors.green.withOpacity(
                                                                                .18,
                                                                              )
                                                                            : Colors.orange.withOpacity(
                                                                                .18,
                                                                              ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                          999,
                                                                        ),
                                                                      ),
                                                                      child: Text(
                                                                        isVerified
                                                                            ? l10n.translate(
                                                                                'verified',
                                                                              )
                                                                            : l10n.translate(
                                                                                'not_verified',
                                                                              ),
                                                                        style:
                                                                            TextStyle(
                                                                          color: isVerified
                                                                              ? Colors.greenAccent
                                                                              : Colors.orangeAccent,
                                                                          fontWeight:
                                                                              FontWeight.w800,
                                                                          fontSize:
                                                                              11,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 12,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child:
                                                                          _MiniStatTile(
                                                                        icon: Icons
                                                                            .star_outline,
                                                                        label:
                                                                            l10n.translate(
                                                                          'rating',
                                                                        ),
                                                                        value: rating >
                                                                                0
                                                                            ? rating.toStringAsFixed(
                                                                                1,
                                                                              )
                                                                            : l10n.translate(
                                                                                'new_label',
                                                                              ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Expanded(
                                                                      child:
                                                                          _MiniStatTile(
                                                                        icon: Icons
                                                                            .inventory_2_outlined,
                                                                        label:
                                                                            l10n.translate(
                                                                          'completed_orders',
                                                                        ),
                                                                        value:
                                                                            completedOrders.toString(),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                if (rating > 0) ...[
                                                                  const SizedBox(
                                                                    height: 10,
                                                                  ),
                                                                  Center(
                                                                    child:
                                                                        _buildRatingStars(
                                                                      rating,
                                                                      size: 18,
                                                                    ),
                                                                  ),
                                                                ],
                                                                const SizedBox(
                                                                  height: 10,
                                                                ),
                                                                _InfoRow(
                                                                  label: l10n.translate(
                                                                    'join_date',
                                                                  ),
                                                                  value:
                                                                      _formatJoinedDate(
                                                                    joinedAt,
                                                                  ),
                                                                  isLast: true,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(height: 10),
                                                          SizedBox(
                                                            width: double.infinity,
                                                            child:
                                                                OutlinedButton.icon(
                                                              onPressed: () =>
                                                                  _showWorkerDetailsDialog(
                                                                item,
                                                                isFavorite:
                                                                    isFavorite,
                                                              ),
                                                              icon: const Icon(
                                                                Icons.info_outline,
                                                              ),
                                                              label: Text(
                                                                l10n.translate(
                                                                  'show_all_worker_details',
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          if (workerPhone.isNotEmpty) ...[
                                                            const SizedBox(
                                                              height: 14,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child:
                                                                      OutlinedButton.icon(
                                                                    onPressed:
                                                                        () =>
                                                                            _makePhoneCall(
                                                                      workerPhone,
                                                                    ),
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .call_outlined,
                                                                    ),
                                                                    label: Text(
                                                                      l10n.translate(
                                                                        'call',
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 10,
                                                                ),
                                                                Expanded(
                                                                  child:
                                                                      OutlinedButton.icon(
                                                                    onPressed:
                                                                        () =>
                                                                            _openWhatsApp(
                                                                      workerPhone,
                                                                    ),
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .chat_outlined,
                                                                    ),
                                                                    label: Text(
                                                                      l10n.translate(
                                                                        'whatsapp',
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                          if (status == 'pending') ...[
                                                            const SizedBox(height: 14),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child:
                                                                      FilledButton(
                                                                    onPressed:
                                                                        isSubmitting
                                                                            ? null
                                                                            : () => _acceptOffer(
                                                                                  offerId: item.offerId,
                                                                                  workerId: workerId,
                                                                                ),
                                                                    child: Text(
                                                                      l10n.translate(
                                                                        'accept_offer',
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 10,
                                                                ),
                                                                Expanded(
                                                                  child:
                                                                      OutlinedButton(
                                                                    onPressed:
                                                                        isSubmitting
                                                                            ? null
                                                                            : () => _rejectOffer(
                                                                                  offerId: item.offerId,
                                                                                ),
                                                                    child: Text(
                                                                      l10n.translate(
                                                                        'reject',
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isSubmitting)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'accepted':
        return l10n.translate('accepted');
      case 'rejected':
        return l10n.translate('rejected');
      default:
        return l10n.translate('waiting_decision');
    }
  }
}

class _OfferViewData {
  final String offerId;
  final Map<String, dynamic> offerData;
  final String workerId;
  final Map<String, dynamic> workerData;

  const _OfferViewData({
    required this.offerId,
    required this.offerData,
    required this.workerId,
    required this.workerData,
  });
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withOpacity(.08)),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white10,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DialogInfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withOpacity(.08)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
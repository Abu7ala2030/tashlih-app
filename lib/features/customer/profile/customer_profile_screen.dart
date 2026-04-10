import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../data/services/firestore_paths.dart';
import '../../../providers/auth_provider.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<_CustomerProfileViewModel> _loadViewModel(String uid) async {
    final userFuture = _db.collection(FirestorePaths.users).doc(uid).get();

    final requestsFuture = _db
        .collection(FirestorePaths.requests)
        .where('customerId', isEqualTo: uid)
        .get();

    final favoritesFuture = _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('favoriteWorkers')
        .get();

    final notificationsFuture = _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final results = await Future.wait([
      userFuture,
      requestsFuture,
      favoritesFuture,
      notificationsFuture,
    ]);

    final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final requestsSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final favoritesSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final notificationsSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

    final userData = userDoc.data() ?? <String, dynamic>{};

    final name = (userData['name'] ?? '').toString().trim();
    final phone = (userData['phone'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();

    final savedAddresses = <String>{};
    for (final doc in requestsSnap.docs) {
      final data = doc.data();
      final address = (data['deliveryAddress'] ?? '').toString().trim();
      if (address.isNotEmpty) {
        savedAddresses.add(address);
      }
    }

    return _CustomerProfileViewModel(
      name: name,
      phone: phone,
      email: email,
      requestsCount: requestsSnap.docs.length,
      favoritesCount: favoritesSnap.docs.length,
      unreadNotificationsCount: notificationsSnap.docs.length,
      savedAddresses: savedAddresses.toList(),
    );
  }

  Future<void> _saveProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _db.collection(FirestorePaths.users).doc(uid).set({
      'name': name.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showSupportSheet() {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('support'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.translate('support_sheet_description'),
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPersonalDataSheet({
    required String uid,
    required _CustomerProfileViewModel data,
  }) {
    final l10n = AppLocalizations.of(context);

    final nameController = TextEditingController(text: data.name);
    final phoneController = TextEditingController(text: data.phone);

    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('personal_data'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InputField(
                      controller: nameController,
                      label: l10n.translate('name'),
                      hint: l10n.translate('enter_name'),
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: phoneController,
                      label: l10n.translate('phone'),
                      hint: '05xxxxxxxx',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final phone = phoneController.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.translate('enter_name_error'),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.translate('enter_phone_error'),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);

                                try {
                                  await _saveProfile(
                                    uid: uid,
                                    name: name,
                                    phone: phone,
                                  );

                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  setState(() {});

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.translate('saved_successfully'),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${l10n.translate('save_failed')}: $e',
                                      ),
                                    ),
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => isSaving = false);
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.translate('save')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  void _showAddressesSheet(List<String> addresses) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.translate('saved_addresses'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: addresses.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.translate('no_addresses_long'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.7,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: addresses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final address = addresses[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D21),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationsSheet(String uid) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.translate('latest_notifications'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection(FirestorePaths.users)
                        .doc(uid)
                        .collection('notifications')
                        .orderBy('createdAt', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.translate('no_notifications'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = docs[index].data();
                          final title =
                              (item['title'] ?? l10n.translate('notification'))
                                  .toString();
                          final body = (item['body'] ?? '').toString();

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D21),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  body.isEmpty
                                      ? l10n.translate('no_details')
                                      : body,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final uid = auth.uid;

    if (uid == null || uid.isEmpty) {
      return Scaffold(
        body: const AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: _ProfileMessage(textKey: 'no_authenticated_user'),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<_CustomerProfileViewModel>(
      future: _loadViewModel(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppGradientBackground(
              child: SafeArea(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: AppGradientBackground(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${l10n.translate('load_profile_failed')}: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final data = snapshot.data ?? const _CustomerProfileViewModel.empty();

        final displayName =
            data.name.isNotEmpty ? data.name : l10n.translate('user');
        final displayPhone =
            data.phone.isNotEmpty ? data.phone : l10n.translate('not_added');
        final displayEmail =
            data.email.isNotEmpty ? data.email : l10n.translate('not_added');

        return Scaffold(
          body: AppGradientBackground(
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('profile'),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.translate('profile_subtitle'),
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF20252B), Color(0xFF171A1F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.person, size: 34),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    displayPhone,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    displayEmail,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.translate('customer'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MiniStatCard(
                              label: l10n.translate('my_requests'),
                              value: data.requestsCount.toString(),
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: l10n.translate('addresses'),
                              value: data.savedAddresses.length.toString(),
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MiniStatCard(
                              label: l10n.translate('notifications'),
                              value: data.unreadNotificationsCount.toString(),
                              icon: Icons.notifications_none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Text(
                        l10n.translate('settings'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          _ProfileTile(
                            icon: Icons.person_outline,
                            title: l10n.translate('personal_data'),
                            subtitle: l10n.translate('edit_profile'),
                            onTap: () => _showPersonalDataSheet(
                              uid: uid,
                              data: data,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.location_on_outlined,
                            title: l10n.translate('addresses'),
                            subtitle: l10n.translate('view_addresses'),
                            onTap: () => _showAddressesSheet(data.savedAddresses),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.notifications_none,
                            title: l10n.translate('notifications'),
                            subtitle: l10n.translate('view_notifications'),
                            onTap: () => _showNotificationsSheet(uid),
                          ),
                          const SizedBox(height: 12),
                          _ProfileTile(
                            icon: Icons.support_agent_outlined,
                            title: l10n.translate('support'),
                            subtitle: l10n.translate('support_short'),
                            onTap: _showSupportSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2B1D1D),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  await context.read<AuthProvider>().signOut();
                                },
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l10n.translate('logout')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white10,
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
      ],
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  final String textKey;

  const _ProfileMessage({
    required this.textKey,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).translate(textKey),
    );
  }
}

class _CustomerProfileViewModel {
  final String name;
  final String phone;
  final String email;
  final int requestsCount;
  final int favoritesCount;
  final int unreadNotificationsCount;
  final List<String> savedAddresses;

  const _CustomerProfileViewModel({
    required this.name,
    required this.phone,
    required this.email,
    required this.requestsCount,
    required this.favoritesCount,
    required this.unreadNotificationsCount,
    required this.savedAddresses,
  });

  const _CustomerProfileViewModel.empty()
      : name = '',
        phone = '',
        email = '',
        requestsCount = 0,
        favoritesCount = 0,
        unreadNotificationsCount = 0,
        savedAddresses = const [];
}
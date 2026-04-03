import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/home_provider.dart';
import '../../../providers/request_provider.dart';

class PartRequestScreen extends StatefulWidget {
  const PartRequestScreen({super.key});

  @override
  State<PartRequestScreen> createState() => _PartRequestScreenState();
}

class _PartRequestScreenState extends State<PartRequestScreen> {
  final partNameController = TextEditingController();
  final notesController = TextEditingController();
  final cityController = TextEditingController();
  final phoneController = TextEditingController();

  bool needsShipping = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final selectedVehicle = context.read<HomeProvider>().selectedVehicle;
    if (selectedVehicle != null) {
      cityController.text = (selectedVehicle['city'] ?? '').toString();
      phoneController.text = (selectedVehicle['contactPhone'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    partNameController.dispose();
    notesController.dispose();
    cityController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final selectedVehicle = context.read<HomeProvider>().selectedVehicle;

    if (selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مركبة محددة')),
      );
      return;
    }

    if (partNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم القطعة')),
      );
      return;
    }

    if (cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال المدينة')),
      );
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم التواصل')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await context.read<RequestProvider>().createRequestFromVehicle(
            vehicle: selectedVehicle,
            partName: partNameController.text.trim(),
            city: cityController.text.trim(),
            phone: phoneController.text.trim(),
            notes: notesController.text.trim(),
            needsShipping: needsShipping,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الطلب بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال الطلب: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = context.watch<HomeProvider>().selectedVehicle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب قطعة'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selectedVehicle != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المركبة المختارة: ${selectedVehicle['make'] ?? ''} ${selectedVehicle['model'] ?? ''} ${selectedVehicle['year'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'التشليح: ${(selectedVehicle['scrapyardName'] ?? 'غير محدد').toString()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'المدينة: ${(selectedVehicle['city'] ?? 'غير محدد').toString()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _InputField(
            controller: partNameController,
            label: 'اسم القطعة',
            hint: 'مثال: باب أمامي يمين',
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: notesController,
            label: 'وصف إضافي',
            hint: 'أي تفاصيل تساعد في تحديد القطعة',
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: cityController,
            label: 'المدينة',
            hint: 'مثال: الدمام',
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: phoneController,
            label: 'رقم التواصل',
            hint: '05xxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: needsShipping,
            onChanged: (value) {
              setState(() {
                needsShipping = value;
              });
            },
            title: const Text('أحتاج شحن للقطعة'),
            subtitle:
                const Text('فعّلها إذا كنت تريد توصيل القطعة إلى عنوانك'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال الطلب'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
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
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
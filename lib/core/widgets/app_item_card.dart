import 'package:flutter/material.dart';

class AppItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onTap;
  final List<Widget>? actions;

  const AppItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.statusText,
    required this.statusColor,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 92, height: 92, fit: BoxFit.cover)
                      : Container(
                          width: 92,
                          height: 92,
                          color: Colors.black26,
                          child: const Icon(Icons.image_outlined),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: actions!),
            ]
          ],
        ),
      ),
    );
  }
}

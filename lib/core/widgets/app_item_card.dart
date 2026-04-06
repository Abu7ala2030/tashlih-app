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
    return RepaintBoundary(
      child: InkWell(
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
                  _CardImage(imageUrl: imageUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
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
                            Expanded(
                              child: Text(
                                statusText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  final String imageUrl;

  const _CardImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              errorBuilder: (context, error, stackTrace) {
                return const _FallbackCardImage();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 92,
                  height: 92,
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            )
          : const _FallbackCardImage(),
    );
  }
}

class _FallbackCardImage extends StatelessWidget {
  const _FallbackCardImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      color: Colors.black26,
      child: const Icon(Icons.image_outlined),
    );
  }
}

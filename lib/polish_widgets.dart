import 'package:flutter/material.dart';

const double kPolishRadius = 16;
const double kSpace4 = 4;
const double kSpace8 = 8;
const double kSpace12 = 12;
const double kSpace16 = 16;
const double kSpace24 = 24;

class AppSkeletonList extends StatelessWidget {
  final int count;
  const AppSkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(kSpace16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: kSpace8),
      itemBuilder: (_, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(kSpace12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: s.onSurface.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: index.isEven ? 150 : 110,
                      decoration: BoxDecoration(
                        color: s.onSurface.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: kSpace8),
                    Container(
                      height: 10,
                      width: index.isEven ? 210 : 165,
                      decoration: BoxDecoration(
                        color: s.onSurface.withValues(alpha: .055),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const AppEmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kSpace24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: s.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: s.primary),
            ),
            const SizedBox(height: kSpace16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: kSpace8),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: s.onSurfaceVariant, height: 1.45)),
            ],
          ],
        ),
      ),
    );
  }
}

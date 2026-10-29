import 'package:flutter/material.dart';

/// Placeholder rows shown while the first load is running, so the screen keeps
/// its shape instead of showing a lone spinner.
class VisitorListSkeleton extends StatelessWidget {
  const VisitorListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading visitors',
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  static const Color _bone = Color(0xFFE6EAEE);

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Bone(height: 16, widthFactor: 0.5)),
                SizedBox(width: 12),
                _Bone(height: 22, width: 76),
              ],
            ),
            SizedBox(height: 10),
            _Bone(height: 12, widthFactor: 0.65),
            SizedBox(height: 8),
            _Bone(height: 12, widthFactor: 0.3),
          ],
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.height, this.width, this.widthFactor});

  final double height;
  final double? width;
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _SkeletonCard._bone,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    if (widthFactor == null) return box;
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(widthFactor: widthFactor, child: box),
    );
  }
}

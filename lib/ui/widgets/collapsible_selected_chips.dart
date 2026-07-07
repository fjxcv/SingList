import 'package:flutter/material.dart';

class CollapsibleSelectedChips extends StatefulWidget {
  const CollapsibleSelectedChips({
    super.key,
    required this.chips,
    this.collapseThreshold = 3,
    this.countLabelBuilder,
    this.header,
  });

  final List<Widget> chips;
  final int collapseThreshold;
  final String Function(int count)? countLabelBuilder;
  final Widget? header;

  @override
  State<CollapsibleSelectedChips> createState() =>
      _CollapsibleSelectedChipsState();
}

class _CollapsibleSelectedChipsState extends State<CollapsibleSelectedChips> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.chips.isEmpty) return const SizedBox.shrink();

    final threshold = widget.collapseThreshold;
    final shouldCollapse = widget.chips.length > threshold;
    final visibleChips = !shouldCollapse || expanded
        ? widget.chips
        : widget.chips.take(threshold).toList();
    final countLabel = (widget.countLabelBuilder ?? _defaultCountLabel)(
      widget.chips.length,
    );

    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...visibleChips,
              if (shouldCollapse && !expanded)
                ActionChip(
                  label: Text(countLabel),
                  onPressed: () => setState(() => expanded = true),
                ),
            ],
          ),
          if (shouldCollapse && expanded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton(
                onPressed: () => setState(() => expanded = false),
                child: const Text('收起'),
              ),
            ),
        ],
      ),
    );
  }

  static String _defaultCountLabel(int count) => '?? $count ?';
}

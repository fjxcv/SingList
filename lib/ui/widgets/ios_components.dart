import 'package:flutter/material.dart';

/// iOS Human Interface Guidelines color tokens.
abstract final class AppColors {
  static const groupedBackground = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const label = Color(0xFF000000);
  static const secondaryLabel = Color(0x993C3C43);
  static const separator = Color(0xFFC6C6C8);
  static const systemBlue = Color(0xFF007AFF);
  static const searchBackground = Color(0xFFE5E5EA);
  static const destructive = Color(0xFFFF3B30);
  static const lightBlueFill = Color(0xFFE0F0FF);
  static const grayButtonFill = Color(0xFFF0F0F5);
  static const badgeBackground = Color(0xFFEBEBF0);
}

abstract final class AppRadii {
  static const small = 10.0;
  static const medium = 12.0;
  static const large = 16.0;
}

class IosLargeTitleHeader extends StatelessWidget {
  const IosLargeTitleHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: AppColors.label,
                height: 1.1,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class IosIconAction extends StatelessWidget {
  const IosIconAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color = AppColors.systemBlue,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

class IosSearchField extends StatelessWidget {
  const IosSearchField({
    super.key,
    required this.hintText,
    this.onChanged,
    this.controller,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.searchBackground,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 17, color: AppColors.label),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 17, color: AppColors.secondaryLabel),
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.secondaryLabel),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }
}

class IosFilterChips extends StatelessWidget {
  const IosFilterChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.systemBlue : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: selected ? null : Border.all(color: AppColors.separator, width: 0.5),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.surface : AppColors.secondaryLabel,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class IosGroupedSection extends StatelessWidget {
  const IosGroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Text(
                header!,
                style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: ColoredBox(
              color: AppColors.surface,
              child: Column(children: _withDividers(children)),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 6),
              child: Text(
                footer!,
                style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    if (items.isEmpty) return items;
    final result = <Widget>[items.first];
    for (var i = 1; i < items.length; i++) {
      result.add(const Divider(height: 0.5, thickness: 0.5, color: AppColors.separator, indent: 16));
      result.add(items[i]);
    }
    return result;
  }
}

class IosListRow extends StatelessWidget {
  const IosListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.lightBlueFill.withValues(alpha: 0.35) : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!
              else if (showChevron)
                const Icon(Icons.chevron_right, size: 20, color: Color(0x4D3C3C43)),
            ],
          ),
        ),
      ),
    );
  }
}

class IosIndexBadge extends StatelessWidget {
  const IosIndexBadge({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.badgeBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryLabel,
        ),
      ),
    );
  }
}

class IosPrimaryButton extends StatelessWidget {
  const IosPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.systemBlue,
          foregroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.medium)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                  Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

class IosSecondaryButton extends StatelessWidget {
  const IosSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightBlueFill,
          foregroundColor: AppColors.systemBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.medium)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class IosGrayButton extends StatelessWidget {
  const IosGrayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.grayButtonFill,
          foregroundColor: AppColors.secondaryLabel,
          side: const BorderSide(color: AppColors.separator, width: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.medium)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class IosSongCard extends StatelessWidget {
  const IosSongCard({super.key, required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.label),
          ),
          const SizedBox(height: 8),
          Text(
            artist,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

class IosSheetHandle extends StatelessWidget {
  const IosSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.separator,
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }
}

class IosSegmentedControl extends StatelessWidget {
  const IosSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.searchBackground,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.label : AppColors.secondaryLabel,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

Future<T?> showIosBottomSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.groupedBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
        ),
        child: Column(
          children: [
            const IosSheetHandle(),
            Expanded(child: SingleChildScrollView(controller: scrollController, child: child)),
          ],
        ),
      ),
    ),
  );
}

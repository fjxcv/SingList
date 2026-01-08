import 'package:flutter/material.dart';

class BottomFabAction extends StatelessWidget {
  const BottomFabAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

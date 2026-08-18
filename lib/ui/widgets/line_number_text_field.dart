import 'package:flutter/material.dart';

class LineNumberTextField extends StatefulWidget {
  const LineNumberTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.focusNode,
    this.errorText,
    this.helperText,
    this.minLines = 8,
    this.maxLines = 20,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? errorText;
  final String? helperText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  State<LineNumberTextField> createState() => _LineNumberTextFieldState();
}

class _LineNumberTextFieldState extends State<LineNumberTextField> {
  static const _gutterWidth = 48.0;
  static const _horizontalTextPadding = 12.0;
  static const _verticalTextPadding = 16.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant LineNumberTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ) ??
        const TextStyle(fontSize: 16, height: 1.5);
    final numberStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        const TextStyle(fontSize: 12, height: 1.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth =
            constraints.maxWidth - _gutterWidth - _horizontalTextPadding * 2;
        return Stack(
          children: [
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              scrollController: _scrollController,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              style: textStyle,
              strutStyle: StrutStyle.fromTextStyle(
                textStyle,
                forceStrutHeight: true,
              ),
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                labelText: widget.labelText,
                alignLabelWithHint: true,
                errorText: widget.errorText,
                helperText: widget.helperText,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.fromLTRB(
                  _gutterWidth + _horizontalTextPadding,
                  _verticalTextPadding,
                  _horizontalTextPadding,
                  _verticalTextPadding,
                ),
              ),
            ),
            Positioned(
              left: 1,
              top: 1,
              bottom: widget.errorText == null && widget.helperText == null
                  ? 1
                  : 25,
              width: _gutterWidth,
              child: Semantics(
                label: '行号：${List.generate(
                  widget.controller.text.split('\n').length,
                  (index) => index + 1,
                ).join('、')}',
                child: IgnorePointer(
                  child: ClipRect(
                    child: CustomPaint(
                      painter: _LineNumberPainter(
                        controller: widget.controller,
                        scrollController: _scrollController,
                        textStyle: textStyle,
                        numberStyle: numberStyle,
                        textWidth: textWidth > 1 ? textWidth : 1,
                        topPadding: _verticalTextPadding,
                        gutterWidth: _gutterWidth,
                        textDirection: Directionality.of(context),
                        dividerColor: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LineNumberPainter extends CustomPainter {
  _LineNumberPainter({
    required this.controller,
    required this.scrollController,
    required this.textStyle,
    required this.numberStyle,
    required this.textWidth,
    required this.topPadding,
    required this.gutterWidth,
    required this.textDirection,
    required this.dividerColor,
  }) : super(repaint: Listenable.merge([controller, scrollController]));

  final TextEditingController controller;
  final ScrollController scrollController;
  final TextStyle textStyle;
  final TextStyle numberStyle;
  final double textWidth;
  final double topPadding;
  final double gutterWidth;
  final TextDirection textDirection;
  final Color dividerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scrollOffset =
        scrollController.hasClients ? scrollController.offset : 0.0;
    final lines = controller.text.split('\n');
    var lineTop = topPadding - scrollOffset;

    canvas.drawLine(
      Offset(gutterWidth - 1, 8),
      Offset(gutterWidth - 1, size.height - 8),
      Paint()
        ..color = dividerColor
        ..strokeWidth = 1,
    );

    for (var index = 0; index < lines.length; index++) {
      final linePainter = TextPainter(
        text: TextSpan(
            text: lines[index].isEmpty ? ' ' : lines[index], style: textStyle),
        textDirection: textDirection,
        strutStyle: StrutStyle.fromTextStyle(
          textStyle,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: textWidth);
      final lineHeight = linePainter.height;
      if (lineTop + lineHeight >= 0 && lineTop <= size.height) {
        final numberPainter = TextPainter(
          text: TextSpan(text: '${index + 1}', style: numberStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
        )..layout(maxWidth: gutterWidth - 12);
        numberPainter.paint(
          canvas,
          Offset(
            gutterWidth - numberPainter.width - 9,
            lineTop + (lineHeight - numberPainter.height) / 2,
          ),
        );
      }
      lineTop += lineHeight;
      if (lineTop > size.height && index < lines.length - 1) break;
    }
  }

  @override
  bool shouldRepaint(covariant _LineNumberPainter oldDelegate) {
    return oldDelegate.textWidth != textWidth ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.numberStyle != numberStyle ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.dividerColor != dividerColor;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/ui/widgets/line_number_text_field.dart';

void main() {
  testWidgets('line numbers update without changing the lyrics text',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: '第一行\n第二行');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LineNumberTextField(
              controller: controller,
              labelText: '歌词',
              minLines: 3,
              maxLines: 4,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('行号：1、2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '第一行\n第二行\n第三行');
    await tester.pump();

    expect(find.bySemanticsLabel('行号：1、2、3'), findsOneWidget);
    expect(controller.text, '第一行\n第二行\n第三行');
    semantics.dispose();
  });

  testWidgets('long lyrics can scroll with the gutter attached',
      (tester) async {
    final controller = TextEditingController(
      text: List.generate(50, (index) => '第 ${index + 1} 行').join('\n'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LineNumberTextField(
            controller: controller,
            labelText: '歌词',
            minLines: 3,
            maxLines: 4,
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.scrollController, isNotNull);
    await tester.drag(find.byType(TextField), const Offset(0, -250));
    await tester.pump();

    expect(field.scrollController!.offset, greaterThan(0));
    expect(controller.text.split('\n'), hasLength(50));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:cateredtoyou/widgets/themed_app_bar.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/widgets/custom_drawer.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,          // ← NEW
    this.actions,
    this.fab,
  });

  final String               title;
  final Widget               body;
  final Widget?              leading;   // ← NEW
  final List<Widget>?        actions;
  final FloatingActionButton? fab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ThemedAppBar(           // pass to ThemedAppBar
        title,
        leading: leading,             // ← NEW
        actions: actions,
      ),
      drawer: const CustomDrawer(),
      bottomNavigationBar: const BottomToolbar(),
      floatingActionButton: fab,
      body: body,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar(
    this.title, {
    this.leading,          // ← NEW
    this.actions,
    this.bottom,
    super.key,
  });

  final String title;
  final Widget? leading;   // ← NEW
  final List<Widget>? actions;
   final PreferredSizeWidget? bottom; 

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: leading,    // ← NEW
      actions: actions,
      bottom: bottom, 
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1565C0),
              Color(0xFF1E88E5),
              Color(0xFF42A5F5),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

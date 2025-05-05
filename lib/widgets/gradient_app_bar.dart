import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar(
    this.title, {
    this.leading,          // ← NEW
    this.actions,
    this.bottom,
    this.elevation = 0,
    super.key,
  });

  final Widget title;
  final Widget? leading;   // ← NEW
  final List<Widget>? actions;
   final PreferredSizeWidget? bottom; 
   final double elevation;

  @override
  Size get preferredSize =>  Size.fromHeight(   kToolbarHeight +
        (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      leading: leading,    // ← NEW
      actions: actions,
      bottom: bottom, 
     // backgroundColor: Colors.transparent,
     backgroundColor: const Color(0xFF0D47A1),
      elevation: elevation,
      //elevation: 0,
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

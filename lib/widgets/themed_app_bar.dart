import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/services/theme_manager.dart';
import 'package:cateredtoyou/widgets/gradient_app_bar.dart';

class ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ThemedAppBar(
    this.title, {
    super.key,
    this.leading,          // ← NEW
    this.actions,
    this.bottom,
    this.elevation = 0,
  });

  final Widget title;
  final Widget? leading;   // ← NEW
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom; 
  final double elevation; 

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight +          // 56
        (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final tm = context.watch<ThemeManager>();

    return tm.preset == ThemePreset.royalBlue
        ? GradientAppBar(
            title,
            leading: leading,         // ← NEW
            actions: actions,
            bottom: bottom,
            elevation: elevation,
          )
        : AppBar(
            title: title,
            leading: leading,         // ← NEW
            actions: actions,
             bottom: bottom,
             elevation: elevation,
          );
  }
}

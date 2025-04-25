import 'package:flutter/material.dart';

/// Glossy, multi-stop blue gradient header.
/// You can set [height] or let the parent constrain it.
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, this.height = 100});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Makes the drop-shadow easy; keeps background transparent elsewhere
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.25),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1) main gradient background ───────────────────────────
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0D47A1), // deep navy
                    Color(0xFF1565C0), // royal blue
                    Color(0xFF1E88E5), // bright blue
                    Color(0xFF42A5F5), // light azure
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // ── 2) glossy reflection strip (subtle) ───────────────────
            const Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.45,           // height of the gloss band
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white24,
                        Colors.white10,
                        Colors.white10,
                        Colors.transparent
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // ── 3) title text ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CateredToYou',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

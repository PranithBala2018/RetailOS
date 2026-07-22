import 'package:flutter/material.dart';

/// Shared shape for every form-centric screen (login, forgot password,
/// company setup, ...): full-width on a phone, a centered card with a
/// bounded width on a wide window (Windows desktop) — per SPRINT0.md's
/// "Responsive Android + Windows layouts" requirement. Deliberately
/// implemented with plain `LayoutBuilder`/`ConstrainedBox` rather than a
/// breakpoint package — one constraint doesn't justify a new dependency.
class ResponsiveFormScaffold extends StatelessWidget {
  const ResponsiveFormScaffold({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = 440,
  });

  final String title;
  final Widget child;
  final double maxWidth;

  static const double _wideLayoutBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
            final content = ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            );

            if (!isWide) return content;

            return Center(
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 2,
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

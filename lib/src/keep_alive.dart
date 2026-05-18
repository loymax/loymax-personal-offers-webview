import 'package:flutter/material.dart';

/// Prevents `ListView` / `GridView` / `TabBarView` / any other lazy
/// container from unmounting its child when it scrolls out of the viewport.
///
/// Used internally by the carousel/screen widgets through the `keepAlive`
/// parameter. Not re-exported from the package — it is an implementation
/// detail.
class LoymaxKeepAlive extends StatefulWidget {
  const LoymaxKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<LoymaxKeepAlive> createState() => _LoymaxKeepAliveState();
}

class _LoymaxKeepAliveState extends State<LoymaxKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return widget.child;
  }
}

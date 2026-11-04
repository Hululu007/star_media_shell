import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 多个横向行组成的上下键焦点链（对标催壳盒端）
class FocusableRowsColumn extends StatefulWidget {
  const FocusableRowsColumn({super.key, required this.rows});

  final List<Widget> rows;

  @override
  State<FocusableRowsColumn> createState() => _FocusableRowsColumnState();
}

class _FocusableRowsColumnState extends State<FocusableRowsColumn> {
  final List<FocusScopeNode> _scopes = [];

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FocusableRowsColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    while (_scopes.length < widget.rows.length) {
      _scopes.add(FocusScopeNode(debugLabel: 'row_scope_${_scopes.length}'));
    }
    while (_scopes.length > widget.rows.length) {
      _scopes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final s in _scopes) {
      s.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handle(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        index < _scopes.length - 1) {
      _scopes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && index > 0) {
      _scopes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.rows.length; i++)
          FocusScope(
            node: _scopes[i],
            onKeyEvent: (node, event) => _handle(i, event),
            child: widget.rows[i],
          ),
      ],
    );
  }
}

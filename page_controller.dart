import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class MouseWheelPageView extends StatefulWidget {
  final PageController controller;
  final List<Widget> children;
  final ValueChanged<int>? onPageChanged;
  final Axis scrollDirection;
  final bool reverse;
  final bool pageSnapping;

  const MouseWheelPageView({
    super.key,
    required this.controller,
    required this.children,
    this.onPageChanged,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.pageSnapping = true,
  });

  @override
  State<MouseWheelPageView> createState() => _MouseWheelPageViewState();
}

class _MouseWheelPageViewState extends State<MouseWheelPageView> {
  late PageController _controller;
  double _scrollAccumulator = 0.0;

  // Adjust these values for sensitivity and speed
  static const double _scrollThreshold = 20.0; // smaller = more sensitive
  static const Duration _animationDuration = Duration(milliseconds: 200); // faster

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  void _handleScroll(PointerScrollEvent event) {
    // Accumulate scroll delta
    _scrollAccumulator += widget.scrollDirection == Axis.horizontal
        ? event.scrollDelta.dy
        : event.scrollDelta.dy;

    // Check if we passed the threshold
    if (_scrollAccumulator.abs() >= _scrollThreshold) {
      final int nextPage = _scrollAccumulator > 0
          ? (_controller.page!.round() + 1)
          : (_controller.page!.round() - 1);

      _controller.animateToPage(
        nextPage.clamp(0, widget.children.length - 1),
        duration: _animationDuration,
        curve: Curves.easeInOut,
      );

      // Reset accumulator after page jump
      _scrollAccumulator = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          _handleScroll(signal);
        }
      },
      child: PageView(
        controller: _controller,
        onPageChanged: widget.onPageChanged,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        pageSnapping: widget.pageSnapping,
        children: widget.children,
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

class StadiumButtonBar extends StatelessWidget {
  const StadiumButtonBar({
    super.key,
    required this.buttons,
    this.padding,
    this.margin,
    this.height = 40,
    this.scrollable = false,
  });

  final List<Widget> buttons;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double height;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: ShapeDecoration(color: isDark ? Colors.grey[900] : Colors.grey[50], shape: const StadiumBorder()),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: SizedBox(
          height: height,
          child: scrollable
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: padding,
                  itemCount: buttons.length,
                  itemBuilder: (_, i) => buttons[i],
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
                  children: buttons,
                ),
        ),
      ),
    );
  }
}

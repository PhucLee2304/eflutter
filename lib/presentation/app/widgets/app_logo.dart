import 'package:eflutter/generated/assets.gen.dart';
import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  const AppLogo({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Assets.images.logo.image(width: width, height: height);
  }
}

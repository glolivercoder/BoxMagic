import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CircularLogo extends StatelessWidget {
  final double size;

  const CircularLogo({
    super.key,
    this.size = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          padding: const EdgeInsets.all(4.0),
          child: SvgPicture.asset(
            'assets/images/magicbox_logo.svg',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// Widget para exibir a logo como um avatar
class CircularLogoAvatar extends StatelessWidget {
  final double size;

  const CircularLogoAvatar({
    super.key,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withAlpha(25),
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: SvgPicture.asset(
            'assets/images/magicbox_logo.svg',
            width: size - 4,
            height: size - 4,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

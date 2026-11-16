import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The WhatsApp mark, in WhatsApp's green. Used on the buttons that open a
/// WhatsApp chat. The artwork is the one from the `simple-icons` set (CC0), in
/// `assets/images/whatsapp.svg`; WhatsApp is a trademark of its owner.
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({super.key, this.size = 22});

  /// WhatsApp's brand green.
  static const Color green = Color(0xFF25D366);

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/whatsapp.svg',
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(green, BlendMode.srcIn),
      semanticsLabel: 'WhatsApp',
    );
  }
}

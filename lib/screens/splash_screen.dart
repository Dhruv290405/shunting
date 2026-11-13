import 'package:flutter/material.dart';
import '../i18n/strings.dart';
import '../theme/hmi_colors.dart';
import '../widgets/hmi_widgets.dart';

class SplashScreen extends StatelessWidget {
  final AppLang lang;
  const SplashScreen({super.key, this.lang = AppLang.en});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Hmi.bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/ir-emblem.png',
              width: 150,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            Strings.t(lang, 'splash_welcome'),
            style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.w500, color: Hmi.muted),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Strings.t(lang, 'splash_title'),
              style: const TextStyle(
                fontSize: 76,
                fontWeight: FontWeight.w700,
                color: Hmi.ink,
                letterSpacing: -1.5,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 3000),
            builder: (context, value, _) => HmiProgressBar(value: value),
          ),
          const SizedBox(height: 80),
          Text(
            Strings.t(lang, 'splash_footer'),
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w500, color: Hmi.muted),
          ),
        ],
      ),
    );
  }
}

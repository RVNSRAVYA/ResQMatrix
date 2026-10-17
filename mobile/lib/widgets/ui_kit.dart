import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Gradient page banner used at the top of the main screens.
class GradientHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? footer;
  const GradientHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.icon,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x2211263D), blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: Stack(children: [
        Positioned(
          right: -40,
          top: -56,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .06), width: 30),
            ),
          ),
        ),
        Positioned(
          right: 36,
          bottom: -70,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.mint.withValues(alpha: .10)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(eyebrow.toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF9BE7DA), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 9),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 27, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -.7)),
                if (subtitle != null) ...[
                  const SizedBox(height: 9),
                  Text(subtitle!,
                      style: const TextStyle(color: Color(0xFFD3E4EC), height: 1.45, fontSize: 12.8)),
                ],
                if (footer != null) ...[const SizedBox(height: 15), footer!],
              ]),
            ),
            if (icon != null) ...[
              const SizedBox(width: 16),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: .12)),
                ),
                child: Icon(icon, color: const Color(0xFF99F6E4), size: 40),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// White rounded surface with a subtle border + shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor ?? AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x080D2036), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? step;
  final Widget? trailing;
  const SectionTitle({super.key, required this.title, this.subtitle, this.step, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (step != null) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF14B8A6)]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(step!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -.3)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.amber,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.ink, fontSize: 12, height: 1.45)),
          ),
        ]),
      );
}

/// Icon in a tinted rounded square.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: .16), color.withValues(alpha: .07)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(icon, color: color, size: size * .54),
      );
}

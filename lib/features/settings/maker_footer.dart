import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers.dart';
import 'social_links.dart';

/// Who made this, and where to follow them.
///
/// A port of the website's own `.social-icons` row rather than a new design:
/// one flex line, `flex: 1 1 0` per item so nine marks spread evenly across
/// whatever width there is, the glyphs bare at 1.35rem with no ring around
/// them, brand-coloured at 88% opacity, lifting a pixel and coming to full
/// strength on touch.
///
/// Both of this app's themes are dark, so it is the stylesheet's `.dark` rules
/// that apply — which is why X, GitHub, Medium and TikTok are white here and
/// not the `#000` they take on a light page.
class MakerFooter extends ConsumerWidget {
  const MakerFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Made by Raimon Baudoin — raimonvibe',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'I build things in the open and write about it. Come and say hello.',
            style: TextStyle(fontSize: 13, color: palette.shade200, height: 1.5),
          ),
          const SizedBox(height: 20),
          Semantics(
            container: true,
            label: 'Social links',
            child: Row(
              // The stylesheet's `justify-content: space-between` with every
              // item at `flex: 1 1 0` — Expanded is the same bargain, and it is
              // what keeps nine icons on one line at any phone width.
              children: [
                for (final link in socialLinks)
                  Expanded(child: _SocialIcon(link: link)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Scripture is the World English Bible, in the public domain. '
            'The application code is MIT licensed.',
            style: TextStyle(fontSize: 11, color: palette.shade300, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatefulWidget {
  const _SocialIcon({required this.link});

  final SocialLink link;

  @override
  State<_SocialIcon> createState() => _SocialIconState();
}

class _SocialIconState extends State<_SocialIcon> {
  bool _lit = false;

  /// `font-size: 1.35rem` on a 16px root.
  static const _glyph = 21.6;

  Future<void> _open() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(
        Uri.parse(widget.link.url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open ${widget.link.label}.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      // A phone with no browser for it. Saying so beats a tap that appears to
      // do nothing at all.
      messenger.showSnackBar(
        SnackBar(
          content: Text('Nothing on this device opens ${widget.link.label}.'),
        ),
      );
    }
  }

  void _light(bool on) {
    if (_lit != on) setState(() => _lit = on);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.link.label}, opens outside the app',
      child: Tooltip(
        message: widget.link.label,
        child: InkResponse(
          onTap: _open,
          radius: 26,
          onHighlightChanged: _light,
          onHover: _light,
          child: SizedBox(
            // A 44pt row keeps the touch target legal even though the mark
            // itself is 21.6.
            height: 44,
            child: AnimatedSlide(
              // `transform: translateY(-1px)` on hover.
              offset: _lit ? const Offset(0, -1 / 44) : Offset.zero,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                // `.icon.brands::before { opacity: .88 }`, going to 1 on hover.
                opacity: _lit ? 1.0 : 0.88,
                duration: const Duration(milliseconds: 200),
                child: Center(child: _mark()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mark() {
    final link = widget.link;

    switch (link.fill) {
      case BrandFill.solid:
        return FaIcon(link.icon, size: _glyph, color: link.colour);

      case BrandFill.gradient:
        // `background-clip: text` with a transparent fill — a ShaderMask is
        // Flutter's version of painting the gradient through the glyph.
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => instagramGradient.createShader(bounds),
          child: FaIcon(link.icon, size: _glyph, color: Colors.white),
        );

      case BrandFill.chromatic:
        // `text-shadow: -1.5px -1.5px #25f4ee, 1.5px 1.5px #fe2c55`, which is
        // two offset copies behind the mark rather than a blur.
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(-1.5, -1.5),
              child: FaIcon(link.icon, size: _glyph, color: tiktokCyan),
            ),
            Transform.translate(
              offset: const Offset(1.5, 1.5),
              child: FaIcon(link.icon, size: _glyph, color: tiktokMagenta),
            ),
            FaIcon(link.icon, size: _glyph, color: link.colour),
          ],
        );
    }
  }
}

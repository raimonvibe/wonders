import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// How a brand mark is coloured.
///
/// Three of the nine cannot be a single colour, so the treatment is part of the
/// data rather than a special case buried in the widget.
enum BrandFill {
  /// One flat colour.
  solid,

  /// Instagram's 45° gradient, painted through the glyph.
  gradient,

  /// TikTok's chromatic split: cyan up-left, magenta down-right, mark on top.
  chromatic,
}

/// One place to follow the maker.
class SocialLink {
  const SocialLink({
    required this.label,
    required this.url,
    required this.icon,
    required this.colour,
    this.fill = BrandFill.solid,
  });

  final String label;
  final String url;

  /// Font Awesome's own type since v11, and not an [IconData] — brand marks are
  /// wider than they are tall, so they are drawn with `FaIcon` rather than
  /// squeezed into Material's square box.
  final FaIconData icon;

  /// The platform's colour, as the website's own stylesheet sets it.
  final Color colour;

  final BrandFill fill;
}

/// The colour `.social-icons .icon` inherits in dark mode: `rgba(255,255,255,.72)`.
///
/// Both of this app's themes are dark, so the website's `.dark` rules are the
/// ones that apply — which is also why X, GitHub, Medium and TikTok are white
/// here rather than the `#000` they take on a light page.
const _inherited = Color(0xB8FFFFFF);
const _onDark = Color(0xFFFFFFFF);

/// Instagram's gradient, stop for stop from the stylesheet.
const instagramGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [
    Color(0xFFFFDC80),
    Color(0xFFFCAF45),
    Color(0xFFF77737),
    Color(0xFFF56040),
    Color(0xFFFD1D1D),
    Color(0xFFE1306C),
    Color(0xFFC13584),
    Color(0xFF833AB4),
    Color(0xFF5851DB),
  ],
  stops: [0.0, 0.12, 0.25, 0.38, 0.50, 0.62, 0.75, 0.87, 1.0],
);

/// TikTok's two offset ghosts, from the `text-shadow` rule.
const tiktokCyan = Color(0xFF25F4EE);
const tiktokMagenta = Color(0xFFFE2C55);

/// The nine links, in the order the website lists them.
///
/// URLs are copied from `frontend/src/components/SocialIcons.tsx` rather than
/// reconstructed — several of them are not the obvious handle URL, and the
/// YouTube one is a channel id.
const socialLinks = <SocialLink>[
  SocialLink(
    label: 'Website',
    url: 'https://www.raimonvibe.eu/',
    icon: FontAwesomeIcons.globe,
    // fa-globe is the one `solid` icon, and the stylesheet gives it no colour
    // of its own, so it keeps the inherited grey.
    colour: _inherited,
  ),
  SocialLink(
    label: 'X',
    url: 'https://x.com/raimonvibe/',
    icon: FontAwesomeIcons.xTwitter,
    colour: _onDark,
  ),
  SocialLink(
    label: 'YouTube',
    url: 'https://www.youtube.com/channel/UCDGDNuYb2b2Ets9CYCNVbuA/videos/',
    icon: FontAwesomeIcons.youtube,
    colour: Color(0xFFFF0000),
  ),
  SocialLink(
    label: 'TikTok',
    url: 'https://www.tiktok.com/@raimonvibe/',
    icon: FontAwesomeIcons.tiktok,
    colour: _onDark,
    fill: BrandFill.chromatic,
  ),
  SocialLink(
    label: 'Instagram',
    url: 'https://www.instagram.com/raimonvibe/',
    icon: FontAwesomeIcons.instagram,
    // Painted over by the gradient; kept as a sane fallback for forced-colours.
    colour: Color(0xFFE1306C),
    fill: BrandFill.gradient,
  ),
  SocialLink(
    label: 'Medium',
    url: 'https://medium.com/@raimonvibe/',
    icon: FontAwesomeIcons.medium,
    colour: _onDark,
  ),
  SocialLink(
    label: 'GitHub',
    url: 'https://github.com/raimonvibe/',
    icon: FontAwesomeIcons.github,
    colour: _onDark,
  ),
  SocialLink(
    label: 'LinkedIn',
    url: 'https://www.linkedin.com/in/raimonvibe/',
    icon: FontAwesomeIcons.linkedinIn,
    colour: Color(0xFF0A66C2),
  ),
  SocialLink(
    label: 'Facebook',
    url: 'https://www.facebook.com/profile.php?id=61563450007849',
    icon: FontAwesomeIcons.facebookF,
    colour: Color(0xFF1877F2),
  ),
];

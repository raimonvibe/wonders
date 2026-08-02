import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/wonder.dart';
import 'share_card.dart';

/// Renders a [ShareCard] to a PNG and hands it to the system share sheet.
///
/// The card is never on screen. It is mounted into the overlay just off the
/// left edge — painted, so RepaintBoundary has something to capture, but
/// outside the viewport — held for the frames it takes to lay out, captured,
/// and removed. `Offstage` would be the obvious choice and is the wrong one:
/// offstage subtrees are laid out but not painted, so the capture comes back
/// blank.
class ShareService {
  const ShareService({required this.siteLabel});

  /// Printed on every image. The one piece of branding.
  final String siteLabel;

  /// 3× so the text stays crisp wherever the image is opened.
  static const double _pixelRatio = 3.0;

  Future<void> shareWonder(BuildContext context, Wonder wonder) async {
    if (!wonder.isShareable) return;

    final png = await renderPng(context, wonder);
    final file = File(
      p.join((await getTemporaryDirectory()).path, 'wonder-${wonder.id}.png'),
    );
    await file.writeAsBytes(png, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        // The reference travels as text too, so a platform that strips the
        // image still says where the words came from.
        text: '${wonder.quoteRef} — ${wonder.title}\n$siteLabel',
        subject: wonder.title,
      ),
    );
  }

  /// Exposed separately so a "save to photos" action, or a golden test, can
  /// use the same bytes the share sheet gets.
  Future<Uint8List> renderPng(BuildContext context, Wonder wonder) async {
    // Resolve the overlay before the first await. pendingFonts can take a
    // network round trip, and if the reader backs out of the card in that
    // window the context is defunct — looking the overlay up afterwards throws
    // instead of failing the share quietly.
    final overlay = Overlay.of(context, rootOverlay: true);

    // google_fonts fetches faces lazily. Without this the first share of a
    // session renders in the fallback face and looks like a different app.
    await GoogleFonts.pendingFonts();

    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Far enough left to be off any screen, still inside the paint pass.
        left: -ShareCard.exportSize.width - 200,
        top: 0,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MediaQuery(
            // A fixed context: the export must not inherit the device's text
            // scale, padding or platform brightness, or two phones produce
            // two different images.
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ShareCard(wonder: wonder, siteLabel: siteLabel),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    try {
      final boundary = await _settled(boundaryKey);
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Could not encode the share card as PNG.');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
    }
  }

  /// Waits until the overlay entry has been laid out and painted at least
  /// once. Capturing a boundary that still needs paint yields a blank image,
  /// and on a cold start that takes more than one frame.
  static Future<RenderRepaintBoundary> _settled(GlobalKey key) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final object = key.currentContext?.findRenderObject();
      if (object is RenderRepaintBoundary && !object.debugNeedsPaint) {
        return object;
      }
    }
    throw StateError('The share card never finished painting.');
  }
}

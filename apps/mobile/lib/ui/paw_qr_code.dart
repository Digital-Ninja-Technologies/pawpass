import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../theme/tokens.dart';

/// A QR code drawn with the app's colours: ink squares on white, with the quiet border scanners need.
/// Pass the full text to encode; it is rendered as is (nothing is sent anywhere).
class PawQrCode extends StatelessWidget {
  const PawQrCode({
    super.key,
    required this.data,
    this.size = 200,
    this.semanticLabel = 'QR code',
  });

  final String data;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _QrPainter(data)),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final qr = QrCode(
      payload: QrPayload.fromString(data),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    );
    final image = QrImage(qr);
    const quiet = 2; // modules of white around the code
    final n = image.moduleCount + quiet * 2;
    final cell = size.width / n;

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final ink = Paint()..color = PawColors.ink;
    for (var r = 0; r < image.moduleCount; r++) {
      for (var c = 0; c < image.moduleCount; c++) {
        if (image.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(
              (c + quiet) * cell,
              (r + quiet) * cell,
              // A hair over one cell so neighbouring squares never show seams.
              cell + 0.3,
              cell + 0.3,
            ),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.data != data;
}

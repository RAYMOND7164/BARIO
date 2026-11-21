import 'package:flutter/material.dart';

import '../theme/bario_theme.dart';

/// Symbole de Bario : un « b » géométrique (une tige + un anneau, comme un
/// verre vu de dessus posé sur le comptoir) et un point lumineux.
class MarqueBario extends StatelessWidget {
  const MarqueBario({super.key, this.taille = 40, this.couleur = HC.accent});
  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: taille, child: CustomPaint(painter: _PeintreMarque(couleur)));
}

class _PeintreMarque extends CustomPainter {
  _PeintreMarque(this.couleur);
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    final plein = Paint()..color = couleur..isAntiAlias = true;
    // Tige
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(18 * u, 8 * u, 15 * u, 84 * u), Radius.circular(7.5 * u)), plein);
    // Anneau
    canvas.drawCircle(
        Offset(57 * u, 63 * u),
        21.5 * u,
        Paint()
          ..color = couleur
          ..style = PaintingStyle.stroke
          ..strokeWidth = 15 * u
          ..isAntiAlias = true);
    // Point lumineux
    canvas.drawCircle(Offset(80 * u, 17 * u), 8 * u, plein);
  }

  @override
  bool shouldRepaint(_PeintreMarque old) => old.couleur != couleur;
}

/// Logo complet : symbole + nom « bario » (+ slogan).
class Logo extends StatelessWidget {
  const Logo({super.key, this.taille = 40, this.slogan = true});
  final double taille;
  final bool slogan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MarqueBario(taille: taille * 1.4),
        SizedBox(height: taille * 0.3),
        Text('bario',
            style: TextStyle(
                fontSize: taille,
                fontWeight: FontWeight.w800,
                letterSpacing: -taille * 0.03,
                color: HC.texte,
                height: 1.0)),
        if (slogan) ...[
          SizedBox(height: taille * 0.25),
          Text('GESTION DE BAR & CLUB',
              style: TextStyle(fontSize: taille * 0.22, letterSpacing: 2.2, color: HC.gris, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

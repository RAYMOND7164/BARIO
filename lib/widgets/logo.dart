import 'package:flutter/material.dart';

import '../theme/bario_theme.dart';

/// Pastille de la marque : carré arrondi en dégradé turquoise → corail, avec un « b ».
class PastilleBario extends StatelessWidget {
  const PastilleBario({super.key, this.taille = 40});
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: BC.degrade,
        borderRadius: BorderRadius.circular(taille * 0.3),
        boxShadow: [BoxShadow(color: BC.accent.withValues(alpha: 0.25), blurRadius: taille * 0.4)],
      ),
      child: Text('b',
          style: TextStyle(
              fontSize: taille * 0.68,
              fontWeight: FontWeight.w900,
              color: BC.fond,
              height: 1.0)),
    );
  }
}

/// Nom de la marque : « bario » en minuscules, suivi d'un point corail.
class MotBario extends StatelessWidget {
  const MotBario({super.key, this.taille = 24});
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'bario', style: TextStyle(color: BC.texte)),
        TextSpan(text: '.', style: TextStyle(color: BC.corail)),
      ]),
      style: TextStyle(fontSize: taille, fontWeight: FontWeight.w900, letterSpacing: -taille * 0.03, height: 1.0),
    );
  }
}

/// Logo complet : pastille + nom + slogan.
class Logo extends StatelessWidget {
  const Logo({super.key, this.taille = 40, this.slogan = true});
  final double taille;
  final bool slogan;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PastilleBario(taille: taille * 1.5),
        SizedBox(height: taille * 0.35),
        MotBario(taille: taille * 1.05),
        if (slogan) ...[
          SizedBox(height: taille * 0.22),
          Text('Bar · Lounge · Club',
              style: TextStyle(fontSize: taille * 0.3, letterSpacing: 1.2, color: BC.gris, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

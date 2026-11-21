/// Connexion au projet Supabase et à PowerSync de Bario.
/// La clé publique (publishable) peut figurer dans le logiciel :
/// la sécurité des données est assurée par les règles de la base.
/// Ne jamais mettre ici la clé « secret » ni un mot de passe.
class BarioConfig {
  static const supabaseUrl = 'https://isevkevxuuzewsotryii.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_kp_NEnnsoTfX5nMPur8qsg_b70jUxNg';

  /// Adresse de l'instance PowerSync (synchronisation hors ligne).
  static const powersyncUrl = 'https://6b0147e0d1877570e4e6a212.powersync.journeyapps.com';

  /// Bario sert plusieurs clubs. L'équipe se connecte avec le CODE DU CLUB
  /// (mémorisé une fois sur l'appareil) + un identifiant. Derrière, Supabase
  /// utilise cette adresse interne, propre au club, qui ne reçoit jamais d'e-mail.
  /// Ne plus jamais changer ce domaine une fois des comptes créés.
  static String emailInterne(String identifiant, String codeClub) =>
      '${identifiant.trim().toLowerCase()}@${codeClub.trim().toLowerCase()}.bario.invalid';
}

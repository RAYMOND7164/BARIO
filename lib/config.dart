/// Connexion au projet Supabase et a PowerSync de Bario.
/// La cle publique (publishable) peut figurer dans le logiciel :
/// la securite des donnees est assuree par les regles de la base.
/// Ne jamais mettre ici la cle « secret » ni un mot de passe.
class BarioConfig {
  static const supabaseUrl = 'https://isevkevxuuzewsotryii.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_kp_NEnnsoTfX5nMPur8qsg_b70jUxNg';

  /// Adresse de l'instance PowerSync (synchronisation hors ligne).
  static const powersyncUrl = 'https://A-REMPLACER.powersync.journeyapps.com';

  /// Bario sert plusieurs clubs. L'equipe se connecte avec le CODE DU CLUB
  /// (memorise une fois sur l'appareil) + un identifiant. Derriere, Supabase
  /// utilise cette adresse interne, propre au club, qui ne recoit jamais d'e-mail.
  static String emailInterne(String identifiant, String codeClub) =>
      '${identifiant.trim().toLowerCase()}@${codeClub.trim().toLowerCase()}.bario.invalid';
}

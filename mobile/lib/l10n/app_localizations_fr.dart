// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'DreamCast';

  @override
  String get authEyebrowSignup => 'LA NUIT SE SOUVIENT';

  @override
  String get authEyebrowLogin => 'CONTENT DE VOUS REVOIR';

  @override
  String get authTaglineSignup =>
      'Chaque rêve porte un message.\nApprenez à l\'entendre.';

  @override
  String get authTaglineLogin => 'Vos rêves vous attendaient.';

  @override
  String get authNameHint => 'Nom (facultatif)';

  @override
  String get authEmailHint => 'Adresse e-mail';

  @override
  String get authPasswordHint => 'Mot de passe (8 caractères min.)';

  @override
  String get authSignupButton => 'Commencer le voyage';

  @override
  String get authLoginButton => 'Retourner au rêve';

  @override
  String get authBusy => 'Ouverture de la porte…';

  @override
  String get authSwitchToLogin => 'Vous avez déjà un compte ? Se connecter';

  @override
  String get authSwitchToSignup => 'Nouveau sur DreamCast ? Créer un compte';

  @override
  String get authErrorGeneric =>
      'Une erreur est survenue. Vérifiez vos informations et réessayez.';

  @override
  String get authErrorEmailTaken =>
      'Un compte existe déjà avec cette adresse e-mail. Connectez-vous plutôt.';

  @override
  String get authErrorInvalidCredentials =>
      'Adresse e-mail ou mot de passe incorrect.';

  @override
  String get authErrorInvalidInput =>
      'Saisissez une adresse e-mail valide et un mot de passe d\'au moins 8 caractères.';

  @override
  String get errorOffline =>
      'Impossible de joindre DreamCast. Vérifiez votre connexion et réessayez.';

  @override
  String get legalAgreePrefix => 'En continuant, vous acceptez nos ';

  @override
  String get legalAgreeMiddle => ' et notre ';

  @override
  String get legalAgreeSuffix => '.';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get aiDisclaimer =>
      'Généré par IA à des fins de réflexion et de divertissement — ne constitue pas un avis médical ou psychologique.';

  @override
  String get navDream => 'Rêve';

  @override
  String get navArchive => 'Archives';

  @override
  String get plansPill => 'OFFRES';

  @override
  String get accountTooltip => 'Compte';

  @override
  String get recordEyebrow => 'AVANT QU\'IL NE S\'EFFACE';

  @override
  String get recordTitle => 'Que vous a montré\nla nuit ?';

  @override
  String get recordSubtitle =>
      'Les rêves s\'effacent quelques minutes après le réveil. Écrivez-le ou dictez-le maintenant, tant qu\'il est encore là.';

  @override
  String get recordHint => 'Je survolais une ville faite de verre...';

  @override
  String get recordSubmit => 'Révéler sa signification';

  @override
  String get recordBusy => 'Lecture des signes…';

  @override
  String get recordError =>
      'Le sens est resté caché cette fois. Veuillez réessayer.';

  @override
  String get recordMicStart => 'Dicter votre rêve';

  @override
  String get recordMicStop => 'Arrêter l\'écoute';

  @override
  String get recordMicUnavailable =>
      'La dictée vocale n\'est pas disponible sur cet appareil.';

  @override
  String get historyEyebrow => 'LES ARCHIVES';

  @override
  String get historyTitle => 'Vos rêves';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rêves en mémoire',
      one: '1 rêve en mémoire',
      zero: 'Aucun rêve pour l\'instant',
    );
    return '$_temp0';
  }

  @override
  String get historyErrorTitle => 'Les archives sont hors de portée';

  @override
  String get historyErrorBody =>
      'Impossible de charger vos rêves. Vérifiez votre connexion et réessayez.';

  @override
  String get historyEmptyTitle => 'Rien pour l\'instant';

  @override
  String get historyEmptyBody =>
      'Votre premier rêve reposera ici une fois raconté. Touchez « Rêve » pour noter celui de la nuit dernière.';

  @override
  String get resultTitle => 'VOTRE RÊVE, DÉCODÉ';

  @override
  String get resultMeaning => 'CE QU\'IL SIGNIFIE';

  @override
  String get resultShare => 'Partager votre carte de rêve';

  @override
  String get resultShareText => 'Mon rêve, décodé par DreamCast ✨';

  @override
  String get reportTitle => 'Signaler cette lecture';

  @override
  String get reportSubtitle =>
      'Dites-nous ce qui ne va pas. Les signalements sont examinés par notre équipe.';

  @override
  String get reportReasonOffensive => 'Offensant ou haineux';

  @override
  String get reportReasonHarmful => 'Nuisible ou perturbant';

  @override
  String get reportReasonInaccurate => 'Trompeur';

  @override
  String get reportReasonImage => 'Image inappropriée';

  @override
  String get reportReasonOther => 'Autre chose';

  @override
  String get reportDetailsHint => 'Ajouter des détails (facultatif)';

  @override
  String get reportSend => 'Envoyer le signalement';

  @override
  String get reportSending => 'Envoi…';

  @override
  String get reportThanks => 'Merci — nous allons examiner cette lecture.';

  @override
  String get reportError =>
      'Impossible d\'envoyer votre signalement. Veuillez réessayer.';

  @override
  String get accountFreePlan => 'Offre gratuite';

  @override
  String accountPlan(String plan) {
    return 'Offre $plan';
  }

  @override
  String get manageSubscription => 'Gérer l\'abonnement';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Langue du téléphone';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteTitle => 'Supprimer votre compte ?';

  @override
  String get deleteBody =>
      'Cette action supprime définitivement votre compte, tous vos rêves et lectures, ainsi que vos cartes de rêve. Elle est irréversible.';

  @override
  String get deleteSubscriptionWarning =>
      'La suppression de votre compte n\'annule pas votre abonnement Google Play. Annulez-le dans Google Play › Abonnements pour arrêter les prélèvements.';

  @override
  String get openGooglePlay => 'Ouvrir Google Play';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteDone => 'Votre compte et vos données ont été supprimés.';

  @override
  String get deleteError =>
      'Impossible de supprimer votre compte. Veuillez réessayer.';

  @override
  String get close => 'Fermer';

  @override
  String get paywallEyebrow => 'ABONNEMENT DREAMCAST';

  @override
  String get paywallTitle => 'Choisissez jusqu\'où\nvous voulez aller.';

  @override
  String get paywallSubtitle =>
      'Des offres mensuelles, facturées en toute sécurité par Google Play. Modifiables ou résiliables à tout moment.';

  @override
  String paywallWelcome(String plan) {
    return 'Bienvenue dans $plan ✨';
  }

  @override
  String get paywallNoSubscription =>
      'Aucun abonnement DreamCast actif n\'a été trouvé sur ce compte Google.';

  @override
  String get paywallOpenPlayError =>
      'Impossible d\'ouvrir Google Play. Veuillez réessayer.';

  @override
  String get paywallYourPlan => 'Votre offre';

  @override
  String get perMonth => 'par mois';

  @override
  String paywallPlanSemantics(String plan, String price) {
    return '$plan, $price par mois';
  }

  @override
  String get paywallCurrentPlan => 'Votre offre actuelle';

  @override
  String paywallContinue(String plan) {
    return 'Continuer avec $plan';
  }

  @override
  String paywallSubscribe(String plan, String price) {
    return 'S\'abonner à $plan · $price/mois';
  }

  @override
  String paywallSwitch(String plan, String price) {
    return 'Passer à $plan · $price/mois';
  }

  @override
  String get paywallAndroidOnly =>
      'Les abonnements s\'achètent via Google Play dans l\'application Android DreamCast.';

  @override
  String get paywallBillingUnavailable =>
      'La facturation Google Play n\'est pas disponible sur cet appareil pour le moment. Vérifiez que le Play Store est installé et que vous y êtes connecté.';

  @override
  String get paywallManageTerms =>
      'Gérez, modifiez ou résiliez votre abonnement à tout moment dans Google Play.';

  @override
  String paywallTerms(String price) {
    return '$price par mois, débités sur votre compte Google Play. L\'abonnement se renouvelle automatiquement chaque mois jusqu\'à sa résiliation. Résiliez à tout moment dans Google Play › Abonnements — vous conservez l\'accès jusqu\'à la fin de la période déjà payée.';
  }

  @override
  String get paywallUpgradeNote =>
      'Votre nouvelle offre démarre immédiatement et le temps non utilisé de votre offre actuelle vous est crédité.';

  @override
  String get paywallDowngradeNote =>
      'Votre nouvelle offre démarrera à votre prochaine date de renouvellement.';

  @override
  String get paywallBusy => 'Ouverture de Google Play…';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get plansLoadErrorTitle => 'Impossible de charger les offres';

  @override
  String get checkConnection => 'Vérifiez votre connexion et réessayez.';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get billingPending =>
      'Votre paiement est en attente. Votre offre démarrera dès que Google Play l\'aura confirmé.';

  @override
  String get billingFailed => 'L\'achat n\'a pas pu être finalisé.';

  @override
  String get billingUnverified =>
      'Nous n\'avons pas encore pu confirmer cet achat. Nous réessaierons automatiquement à la prochaine ouverture de DreamCast.';

  @override
  String get billingError =>
      'Google Play Billing a rencontré un problème. Veuillez réessayer.';
}

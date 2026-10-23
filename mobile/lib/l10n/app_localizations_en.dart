// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DreamCast';

  @override
  String get authEyebrowSignup => 'THE NIGHT REMEMBERS';

  @override
  String get authEyebrowLogin => 'WELCOME BACK';

  @override
  String get authTaglineSignup =>
      'Every dream carries a message.\nLearn to hear yours.';

  @override
  String get authTaglineLogin => 'Your dreams have been waiting for you.';

  @override
  String get authNameHint => 'Name (optional)';

  @override
  String get authEmailHint => 'Email';

  @override
  String get authPasswordHint => 'Password (min. 8 characters)';

  @override
  String get authSignupButton => 'Begin the journey';

  @override
  String get authLoginButton => 'Return to the dream';

  @override
  String get authBusy => 'Opening the door…';

  @override
  String get authSwitchToLogin => 'Already have an account? Log in';

  @override
  String get authSwitchToSignup => 'New here? Create an account';

  @override
  String get authErrorGeneric =>
      'Something went wrong. Check your details and try again.';

  @override
  String get authErrorEmailTaken =>
      'An account with this email already exists. Log in instead.';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorInvalidInput =>
      'Enter a valid email and a password of at least 8 characters.';

  @override
  String get errorOffline =>
      'Can\'t reach DreamCast. Check your connection and try again.';

  @override
  String get legalAgreePrefix => 'By continuing you agree to our ';

  @override
  String get legalAgreeMiddle => ' and ';

  @override
  String get legalAgreeSuffix => '.';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get aiDisclaimer =>
      'AI-generated for reflection and entertainment — not medical or psychological advice.';

  @override
  String get navDream => 'Dream';

  @override
  String get navArchive => 'Archive';

  @override
  String get plansPill => 'PLANS';

  @override
  String get accountTooltip => 'Account';

  @override
  String get recordEyebrow => 'BEFORE IT FADES';

  @override
  String get recordTitle => 'What did the night\nshow you?';

  @override
  String get recordSubtitle =>
      'Dreams slip away within minutes of waking. Write or speak it now, while it still lingers.';

  @override
  String get recordHint => 'I was flying over a city made of glass...';

  @override
  String get recordSubmit => 'Reveal its meaning';

  @override
  String get recordBusy => 'Reading the signs…';

  @override
  String get recordError =>
      'The meaning stayed hidden this time. Please try again.';

  @override
  String get recordMicStart => 'Speak your dream';

  @override
  String get recordMicStop => 'Stop listening';

  @override
  String get recordMicUnavailable =>
      'Voice input isn\'t available on this device.';

  @override
  String get historyEyebrow => 'THE ARCHIVE';

  @override
  String get historyTitle => 'Your dreams';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dreams remembered',
      one: '1 dream remembered',
      zero: 'No dreams yet',
    );
    return '$_temp0';
  }

  @override
  String get historyErrorTitle => 'The archive is out of reach';

  @override
  String get historyErrorBody =>
      'We couldn\'t load your dreams. Check your connection and try again.';

  @override
  String get historyEmptyTitle => 'Nothing here yet';

  @override
  String get historyEmptyBody =>
      'Your first dream will rest here once you\'ve told it. Tap Dream to record last night\'s.';

  @override
  String get resultTitle => 'YOUR DREAM, DECODED';

  @override
  String get resultMeaning => 'WHAT IT MEANS';

  @override
  String get resultShare => 'Share your Dream Card';

  @override
  String get resultShareText => 'My dream, decoded by DreamCast ✨';

  @override
  String get reportTitle => 'Report this reading';

  @override
  String get reportSubtitle =>
      'Tell us what went wrong. Reports are reviewed by our team.';

  @override
  String get reportReasonOffensive => 'Offensive or hateful';

  @override
  String get reportReasonHarmful => 'Harmful or upsetting';

  @override
  String get reportReasonInaccurate => 'Misleading';

  @override
  String get reportReasonImage => 'Inappropriate image';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get reportDetailsHint => 'Add details (optional)';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSending => 'Sending…';

  @override
  String get reportThanks => 'Thank you — we\'ll review this reading.';

  @override
  String get reportError => 'Couldn\'t send your report. Please try again.';

  @override
  String get accountFreePlan => 'Free plan';

  @override
  String accountPlan(String plan) {
    return '$plan plan';
  }

  @override
  String get manageSubscription => 'Manage subscription';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Phone language';

  @override
  String get logOut => 'Log out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteTitle => 'Delete your account?';

  @override
  String get deleteBody =>
      'This permanently deletes your account, every dream and reading, and your Dream Cards. It cannot be undone.';

  @override
  String get deleteSubscriptionWarning =>
      'Deleting your account does not cancel your Google Play subscription. Cancel it in Google Play › Subscriptions to stop future charges.';

  @override
  String get openGooglePlay => 'Open Google Play';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get deleteDone => 'Your account and data have been deleted.';

  @override
  String get deleteError => 'Couldn\'t delete your account. Please try again.';

  @override
  String get close => 'Close';

  @override
  String get paywallEyebrow => 'DREAMCAST MEMBERSHIP';

  @override
  String get paywallTitle => 'Choose how deep\nyou want to go.';

  @override
  String get paywallSubtitle =>
      'Monthly plans, billed securely through Google Play. Change or cancel anytime.';

  @override
  String paywallWelcome(String plan) {
    return 'Welcome to $plan ✨';
  }

  @override
  String get paywallNoSubscription =>
      'No active DreamCast subscription was found on this Google account.';

  @override
  String get paywallOpenPlayError =>
      'Couldn\'t open Google Play. Please try again.';

  @override
  String get paywallYourPlan => 'Your plan';

  @override
  String get perMonth => 'per month';

  @override
  String paywallPlanSemantics(String plan, String price) {
    return '$plan, $price per month';
  }

  @override
  String get paywallCurrentPlan => 'Your current plan';

  @override
  String paywallContinue(String plan) {
    return 'Continue with $plan';
  }

  @override
  String paywallSubscribe(String plan, String price) {
    return 'Subscribe to $plan · $price/month';
  }

  @override
  String paywallSwitch(String plan, String price) {
    return 'Switch to $plan · $price/month';
  }

  @override
  String get paywallAndroidOnly =>
      'Subscriptions are purchased through Google Play in the DreamCast Android app.';

  @override
  String get paywallBillingUnavailable =>
      'Google Play Billing is unavailable on this device right now. Make sure the Play Store is installed and signed in.';

  @override
  String get paywallManageTerms =>
      'Manage, change or cancel your subscription anytime in Google Play.';

  @override
  String paywallTerms(String price) {
    return '$price per month, charged to your Google Play account. Renews automatically every month until you cancel. Cancel anytime in Google Play › Subscriptions — you keep access until the end of the period you have paid for.';
  }

  @override
  String get paywallUpgradeNote =>
      'Your upgrade starts now and unused time on your current plan is credited.';

  @override
  String get paywallDowngradeNote =>
      'Your new plan starts at your next renewal date.';

  @override
  String get paywallBusy => 'Opening Google Play…';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get plansLoadErrorTitle => 'Plans couldn\'t load';

  @override
  String get checkConnection => 'Check your connection and try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get billingPending =>
      'Your payment is pending. Your plan starts as soon as Google Play confirms it.';

  @override
  String get billingFailed => 'The purchase could not be completed.';

  @override
  String get billingUnverified =>
      'We couldn\'t confirm this purchase yet. We\'ll retry automatically next time you open DreamCast.';

  @override
  String get billingError =>
      'Google Play Billing ran into a problem. Please try again.';
}

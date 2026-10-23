import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DreamCast'**
  String get appTitle;

  /// No description provided for @authEyebrowSignup.
  ///
  /// In en, this message translates to:
  /// **'THE NIGHT REMEMBERS'**
  String get authEyebrowSignup;

  /// No description provided for @authEyebrowLogin.
  ///
  /// In en, this message translates to:
  /// **'WELCOME BACK'**
  String get authEyebrowLogin;

  /// No description provided for @authTaglineSignup.
  ///
  /// In en, this message translates to:
  /// **'Every dream carries a message.\nLearn to hear yours.'**
  String get authTaglineSignup;

  /// No description provided for @authTaglineLogin.
  ///
  /// In en, this message translates to:
  /// **'Your dreams have been waiting for you.'**
  String get authTaglineLogin;

  /// No description provided for @authNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get authNameHint;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailHint;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password (min. 8 characters)'**
  String get authPasswordHint;

  /// No description provided for @authSignupButton.
  ///
  /// In en, this message translates to:
  /// **'Begin the journey'**
  String get authSignupButton;

  /// No description provided for @authLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Return to the dream'**
  String get authLoginButton;

  /// No description provided for @authBusy.
  ///
  /// In en, this message translates to:
  /// **'Opening the door…'**
  String get authBusy;

  /// No description provided for @authSwitchToLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get authSwitchToLogin;

  /// No description provided for @authSwitchToSignup.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get authSwitchToSignup;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Check your details and try again.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Log in instead.'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email and a password of at least 8 characters.'**
  String get authErrorInvalidInput;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach DreamCast. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @legalAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our '**
  String get legalAgreePrefix;

  /// No description provided for @legalAgreeMiddle.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get legalAgreeMiddle;

  /// No description provided for @legalAgreeSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get legalAgreeSuffix;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated for reflection and entertainment — not medical or psychological advice.'**
  String get aiDisclaimer;

  /// No description provided for @navDream.
  ///
  /// In en, this message translates to:
  /// **'Dream'**
  String get navDream;

  /// No description provided for @navArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get navArchive;

  /// No description provided for @plansPill.
  ///
  /// In en, this message translates to:
  /// **'PLANS'**
  String get plansPill;

  /// No description provided for @accountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTooltip;

  /// No description provided for @recordEyebrow.
  ///
  /// In en, this message translates to:
  /// **'BEFORE IT FADES'**
  String get recordEyebrow;

  /// No description provided for @recordTitle.
  ///
  /// In en, this message translates to:
  /// **'What did the night\nshow you?'**
  String get recordTitle;

  /// No description provided for @recordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dreams slip away within minutes of waking. Write or speak it now, while it still lingers.'**
  String get recordSubtitle;

  /// No description provided for @recordHint.
  ///
  /// In en, this message translates to:
  /// **'I was flying over a city made of glass...'**
  String get recordHint;

  /// No description provided for @recordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Reveal its meaning'**
  String get recordSubmit;

  /// No description provided for @recordBusy.
  ///
  /// In en, this message translates to:
  /// **'Reading the signs…'**
  String get recordBusy;

  /// No description provided for @recordError.
  ///
  /// In en, this message translates to:
  /// **'The meaning stayed hidden this time. Please try again.'**
  String get recordError;

  /// No description provided for @recordMicStart.
  ///
  /// In en, this message translates to:
  /// **'Speak your dream'**
  String get recordMicStart;

  /// No description provided for @recordMicStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get recordMicStop;

  /// No description provided for @recordMicUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input isn\'t available on this device.'**
  String get recordMicUnavailable;

  /// No description provided for @historyEyebrow.
  ///
  /// In en, this message translates to:
  /// **'THE ARCHIVE'**
  String get historyEyebrow;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your dreams'**
  String get historyTitle;

  /// No description provided for @historyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No dreams yet} =1{1 dream remembered} other{{count} dreams remembered}}'**
  String historyCount(int count);

  /// No description provided for @historyErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'The archive is out of reach'**
  String get historyErrorTitle;

  /// No description provided for @historyErrorBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your dreams. Check your connection and try again.'**
  String get historyErrorBody;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your first dream will rest here once you\'ve told it. Tap Dream to record last night\'s.'**
  String get historyEmptyBody;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'YOUR DREAM, DECODED'**
  String get resultTitle;

  /// No description provided for @resultMeaning.
  ///
  /// In en, this message translates to:
  /// **'WHAT IT MEANS'**
  String get resultMeaning;

  /// No description provided for @resultShare.
  ///
  /// In en, this message translates to:
  /// **'Share your Dream Card'**
  String get resultShare;

  /// No description provided for @resultShareText.
  ///
  /// In en, this message translates to:
  /// **'My dream, decoded by DreamCast ✨'**
  String get resultShareText;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this reading'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us what went wrong. Reports are reviewed by our team.'**
  String get reportSubtitle;

  /// No description provided for @reportReasonOffensive.
  ///
  /// In en, this message translates to:
  /// **'Offensive or hateful'**
  String get reportReasonOffensive;

  /// No description provided for @reportReasonHarmful.
  ///
  /// In en, this message translates to:
  /// **'Harmful or upsetting'**
  String get reportReasonHarmful;

  /// No description provided for @reportReasonInaccurate.
  ///
  /// In en, this message translates to:
  /// **'Misleading'**
  String get reportReasonInaccurate;

  /// No description provided for @reportReasonImage.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate image'**
  String get reportReasonImage;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportReasonOther;

  /// No description provided for @reportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add details (optional)'**
  String get reportDetailsHint;

  /// No description provided for @reportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// No description provided for @reportSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get reportSending;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you — we\'ll review this reading.'**
  String get reportThanks;

  /// No description provided for @reportError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your report. Please try again.'**
  String get reportError;

  /// No description provided for @accountFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get accountFreePlan;

  /// No description provided for @accountPlan.
  ///
  /// In en, this message translates to:
  /// **'{plan} plan'**
  String accountPlan(String plan);

  /// No description provided for @manageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get manageSubscription;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Phone language'**
  String get languageSystem;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, every dream and reading, and your Dream Cards. It cannot be undone.'**
  String get deleteBody;

  /// No description provided for @deleteSubscriptionWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account does not cancel your Google Play subscription. Cancel it in Google Play › Subscriptions to stop future charges.'**
  String get deleteSubscriptionWarning;

  /// No description provided for @openGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'Open Google Play'**
  String get openGooglePlay;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account and data have been deleted.'**
  String get deleteDone;

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Please try again.'**
  String get deleteError;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @paywallEyebrow.
  ///
  /// In en, this message translates to:
  /// **'DREAMCAST MEMBERSHIP'**
  String get paywallEyebrow;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how deep\nyou want to go.'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly plans, billed securely through Google Play. Change or cancel anytime.'**
  String get paywallSubtitle;

  /// No description provided for @paywallWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {plan} ✨'**
  String paywallWelcome(String plan);

  /// No description provided for @paywallNoSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active DreamCast subscription was found on this Google account.'**
  String get paywallNoSubscription;

  /// No description provided for @paywallOpenPlayError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Google Play. Please try again.'**
  String get paywallOpenPlayError;

  /// No description provided for @paywallYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get paywallYourPlan;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get perMonth;

  /// No description provided for @paywallPlanSemantics.
  ///
  /// In en, this message translates to:
  /// **'{plan}, {price} per month'**
  String paywallPlanSemantics(String plan, String price);

  /// No description provided for @paywallCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Your current plan'**
  String get paywallCurrentPlan;

  /// No description provided for @paywallContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue with {plan}'**
  String paywallContinue(String plan);

  /// No description provided for @paywallSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to {plan} · {price}/month'**
  String paywallSubscribe(String plan, String price);

  /// No description provided for @paywallSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch to {plan} · {price}/month'**
  String paywallSwitch(String plan, String price);

  /// No description provided for @paywallAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are purchased through Google Play in the DreamCast Android app.'**
  String get paywallAndroidOnly;

  /// No description provided for @paywallBillingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Play Billing is unavailable on this device right now. Make sure the Play Store is installed and signed in.'**
  String get paywallBillingUnavailable;

  /// No description provided for @paywallManageTerms.
  ///
  /// In en, this message translates to:
  /// **'Manage, change or cancel your subscription anytime in Google Play.'**
  String get paywallManageTerms;

  /// No description provided for @paywallTerms.
  ///
  /// In en, this message translates to:
  /// **'{price} per month, charged to your Google Play account. Renews automatically every month until you cancel. Cancel anytime in Google Play › Subscriptions — you keep access until the end of the period you have paid for.'**
  String paywallTerms(String price);

  /// No description provided for @paywallUpgradeNote.
  ///
  /// In en, this message translates to:
  /// **'Your upgrade starts now and unused time on your current plan is credited.'**
  String get paywallUpgradeNote;

  /// No description provided for @paywallDowngradeNote.
  ///
  /// In en, this message translates to:
  /// **'Your new plan starts at your next renewal date.'**
  String get paywallDowngradeNote;

  /// No description provided for @paywallBusy.
  ///
  /// In en, this message translates to:
  /// **'Opening Google Play…'**
  String get paywallBusy;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @plansLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans couldn\'t load'**
  String get plansLoadErrorTitle;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkConnection;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @billingPending.
  ///
  /// In en, this message translates to:
  /// **'Your payment is pending. Your plan starts as soon as Google Play confirms it.'**
  String get billingPending;

  /// No description provided for @billingFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase could not be completed.'**
  String get billingFailed;

  /// No description provided for @billingUnverified.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm this purchase yet. We\'ll retry automatically next time you open DreamCast.'**
  String get billingUnverified;

  /// No description provided for @billingError.
  ///
  /// In en, this message translates to:
  /// **'Google Play Billing ran into a problem. Please try again.'**
  String get billingError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

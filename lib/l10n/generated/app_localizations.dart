import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('zh'),
  ];

  /// Application display name
  ///
  /// In en, this message translates to:
  /// **'InkFrame'**
  String get appTitle;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @errorInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'API key is invalid. Check your provider settings.'**
  String get errorInvalidKey;

  /// No description provided for @errorInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Provider account has insufficient balance.'**
  String get errorInsufficientBalance;

  /// No description provided for @errorContentPolicy.
  ///
  /// In en, this message translates to:
  /// **'The content policy rejected this request.'**
  String get errorContentPolicy;

  /// No description provided for @errorInvalidParameter.
  ///
  /// In en, this message translates to:
  /// **'One or more request parameters are invalid.'**
  String get errorInvalidParameter;

  /// No description provided for @errorNetworkTimeout.
  ///
  /// In en, this message translates to:
  /// **'Network timed out. Please retry.'**
  String get errorNetworkTimeout;

  /// No description provided for @errorNetworkOffline.
  ///
  /// In en, this message translates to:
  /// **'Network is offline. Check your connection.'**
  String get errorNetworkOffline;

  /// No description provided for @errorProviderServer.
  ///
  /// In en, this message translates to:
  /// **'The provider service is unavailable. Please retry.'**
  String get errorProviderServer;

  /// No description provided for @errorProviderBusy.
  ///
  /// In en, this message translates to:
  /// **'The provider is busy. Please retry shortly.'**
  String get errorProviderBusy;

  /// No description provided for @errorPollTimeout.
  ///
  /// In en, this message translates to:
  /// **'Generation did not complete within the time limit.'**
  String get errorPollTimeout;

  /// No description provided for @errorDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download the generated asset.'**
  String get errorDownloadFailed;

  /// No description provided for @errorLocalIO.
  ///
  /// In en, this message translates to:
  /// **'Local disk I/O error. Check space and permissions.'**
  String get errorLocalIO;

  /// No description provided for @errorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by user.'**
  String get errorCancelled;

  /// No description provided for @errorCancelledOnExit.
  ///
  /// In en, this message translates to:
  /// **'Cancelled because the application is exiting.'**
  String get errorCancelledOnExit;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get errorUnknown;

  /// No description provided for @canvasEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Right-click or press + to add a node'**
  String get canvasEmptyHint;

  /// No description provided for @canvasNodeDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'New Node'**
  String get canvasNodeDefaultLabel;

  /// No description provided for @canvasNodeImageType.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get canvasNodeImageType;

  /// No description provided for @canvasAddNode.
  ///
  /// In en, this message translates to:
  /// **'Add Node'**
  String get canvasAddNode;

  /// No description provided for @canvasDeleteNode.
  ///
  /// In en, this message translates to:
  /// **'Delete Node'**
  String get canvasDeleteNode;

  /// No description provided for @canvasNodesSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} node(s) selected'**
  String canvasNodesSelected(int count);

  /// No description provided for @canvasNoCanvasOpen.
  ///
  /// In en, this message translates to:
  /// **'No canvas is open'**
  String get canvasNoCanvasOpen;

  /// No description provided for @canvasCreateSampleCanvas.
  ///
  /// In en, this message translates to:
  /// **'Create sample canvas'**
  String get canvasCreateSampleCanvas;

  /// No description provided for @canvasLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load canvas'**
  String get canvasLoadFailed;

  /// No description provided for @canvasSampleProjectName.
  ///
  /// In en, this message translates to:
  /// **'Sample Project'**
  String get canvasSampleProjectName;

  /// No description provided for @canvasSampleCanvasName.
  ///
  /// In en, this message translates to:
  /// **'Canvas 1'**
  String get canvasSampleCanvasName;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get inspectorTitle;

  /// No description provided for @inspectorPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get inspectorPromptLabel;

  /// No description provided for @inspectorPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the image you want...'**
  String get inspectorPromptHint;

  /// No description provided for @inspectorProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get inspectorProviderLabel;

  /// No description provided for @inspectorResolutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get inspectorResolutionLabel;

  /// No description provided for @inspectorGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get inspectorGenerate;

  /// No description provided for @inspectorGenerateDisabledEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Write a prompt first'**
  String get inspectorGenerateDisabledEmptyPrompt;

  /// No description provided for @inspectorGenerateDisabledNoKey.
  ///
  /// In en, this message translates to:
  /// **'Configure API key in Settings'**
  String get inspectorGenerateDisabledNoKey;

  /// No description provided for @inspectorGenerateNotWiredYet.
  ///
  /// In en, this message translates to:
  /// **'Generation wiring ships in the next slice'**
  String get inspectorGenerateNotWiredYet;

  /// No description provided for @inspectorSelectSingleHint.
  ///
  /// In en, this message translates to:
  /// **'Select a single config node to edit'**
  String get inspectorSelectSingleHint;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsApiKeysSection.
  ///
  /// In en, this message translates to:
  /// **'API Keys'**
  String get settingsApiKeysSection;

  /// No description provided for @settingsApiKeysHint.
  ///
  /// In en, this message translates to:
  /// **'Keys are stored in your system keychain. Nothing is sent off-device.'**
  String get settingsApiKeysHint;

  /// No description provided for @settingsApiKeyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'sk-...'**
  String get settingsApiKeyPlaceholder;

  /// No description provided for @settingsApiKeySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsApiKeySave;

  /// No description provided for @settingsApiKeyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsApiKeyClear;

  /// No description provided for @settingsApiKeySet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get settingsApiKeySet;

  /// No description provided for @settingsApiKeyNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsApiKeyNotSet;

  /// No description provided for @settingsApiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get settingsApiKeySaved;

  /// No description provided for @settingsApiKeyCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get settingsApiKeyCleared;

  /// No description provided for @generationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get generationSuccess;

  /// No description provided for @generationFailure.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get generationFailure;

  /// No description provided for @generationMissingKey.
  ///
  /// In en, this message translates to:
  /// **'API key is missing'**
  String get generationMissingKey;

  /// No description provided for @generationInvalidConfig.
  ///
  /// In en, this message translates to:
  /// **'Invalid configuration: {reason}'**
  String generationInvalidConfig(String reason);

  /// No description provided for @generationProviderNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Provider not registered'**
  String get generationProviderNotRegistered;

  /// No description provided for @resultNodePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for generation'**
  String get resultNodePending;

  /// No description provided for @resultNodeImageMissing.
  ///
  /// In en, this message translates to:
  /// **'Image file missing'**
  String get resultNodeImageMissing;

  /// No description provided for @linkModeStart.
  ///
  /// In en, this message translates to:
  /// **'Start link'**
  String get linkModeStart;

  /// No description provided for @linkModeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a target node to link, or tap empty space to cancel'**
  String get linkModeHint;

  /// No description provided for @linkCreated.
  ///
  /// In en, this message translates to:
  /// **'Link created'**
  String get linkCreated;

  /// No description provided for @linkAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Link already exists'**
  String get linkAlreadyExists;

  /// No description provided for @linkSelfNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Cannot link a node to itself'**
  String get linkSelfNotAllowed;

  /// No description provided for @nodeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete node'**
  String get nodeDelete;

  /// No description provided for @nodeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Node deleted'**
  String get nodeDeleted;

  /// No description provided for @nodeDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete node'**
  String get nodeDeleteFailed;

  /// No description provided for @inspectorInputsLabel.
  ///
  /// In en, this message translates to:
  /// **'Inputs'**
  String get inspectorInputsLabel;

  /// No description provided for @inspectorInputsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No input connections'**
  String get inspectorInputsEmpty;

  /// No description provided for @inspectorRoleReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get inspectorRoleReference;

  /// No description provided for @inspectorRoleFirstFrame.
  ///
  /// In en, this message translates to:
  /// **'First frame'**
  String get inspectorRoleFirstFrame;

  /// No description provided for @inspectorRoleLastFrame.
  ///
  /// In en, this message translates to:
  /// **'Last frame'**
  String get inspectorRoleLastFrame;

  /// No description provided for @inspectorRemoveInput.
  ///
  /// In en, this message translates to:
  /// **'Remove input'**
  String get inspectorRemoveInput;

  /// No description provided for @canvasAddImageNode.
  ///
  /// In en, this message translates to:
  /// **'Add image node'**
  String get canvasAddImageNode;

  /// No description provided for @canvasAddNodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add node'**
  String get canvasAddNodeFailed;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

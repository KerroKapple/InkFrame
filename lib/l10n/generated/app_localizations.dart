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

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

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

  /// No description provided for @errorProviderInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The provider returned an invalid or empty result.'**
  String get errorProviderInvalidResponse;

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

  /// No description provided for @canvasNodeTextType.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get canvasNodeTextType;

  /// No description provided for @canvasNodeVideoType.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get canvasNodeVideoType;

  /// No description provided for @canvasNodeShotType.
  ///
  /// In en, this message translates to:
  /// **'Shot'**
  String get canvasNodeShotType;

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

  /// No description provided for @inspectorAspectRatioLabel.
  ///
  /// In en, this message translates to:
  /// **'Aspect ratio'**
  String get inspectorAspectRatioLabel;

  /// No description provided for @inspectorSeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get inspectorSeedLabel;

  /// No description provided for @inspectorSeedHint.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get inspectorSeedHint;

  /// No description provided for @inspectorNegativePromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Negative prompt'**
  String get inspectorNegativePromptLabel;

  /// No description provided for @inspectorNegativePromptHint.
  ///
  /// In en, this message translates to:
  /// **'What to avoid'**
  String get inspectorNegativePromptHint;

  /// No description provided for @inspectorBatchLabel.
  ///
  /// In en, this message translates to:
  /// **'Batch size'**
  String get inspectorBatchLabel;

  /// No description provided for @inspectorEstimatedCost.
  ///
  /// In en, this message translates to:
  /// **'Est. cost {amount}'**
  String inspectorEstimatedCost(String amount);

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

  /// No description provided for @inspectorStatusSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get inspectorStatusSubmitting;

  /// No description provided for @inspectorStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get inspectorStatusRunning;

  /// No description provided for @inspectorStatusRunningWithProgress.
  ///
  /// In en, this message translates to:
  /// **'Generating... {percent}%'**
  String inspectorStatusRunningWithProgress(int percent);

  /// No description provided for @inspectorStatusErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get inspectorStatusErrorTitle;

  /// No description provided for @inspectorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get inspectorRetry;

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

  /// No description provided for @settingsApiKeySavedUnverified.
  ///
  /// In en, this message translates to:
  /// **'Saved, but the key could not be verified due to a network issue.'**
  String get settingsApiKeySavedUnverified;

  /// No description provided for @settingsApiKeyRejected.
  ///
  /// In en, this message translates to:
  /// **'The provider rejected this key. It was not saved.'**
  String get settingsApiKeyRejected;

  /// No description provided for @settingsApiKeyCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get settingsApiKeyCleared;

  /// No description provided for @settingsThemeSection.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeSection;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get settingsThemeHighContrast;

  /// No description provided for @settingsThemeTextScale.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsThemeTextScale;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsLanguageZh.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get settingsLanguageZh;

  /// No description provided for @settingsStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorageSection;

  /// No description provided for @settingsStorageReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Database location is fixed in this release. Changing it requires a migration not yet implemented.'**
  String get settingsStorageReadOnlyHint;

  /// No description provided for @settingsStorageDatabasePathLabel.
  ///
  /// In en, this message translates to:
  /// **'Database directory'**
  String get settingsStorageDatabasePathLabel;

  /// No description provided for @settingsStorageCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get settingsStorageCopyPath;

  /// No description provided for @settingsStoragePathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get settingsStoragePathCopied;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsAboutAppNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get settingsAboutAppNameLabel;

  /// No description provided for @settingsAboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersionLabel;

  /// No description provided for @settingsAboutSecureStorageLabel.
  ///
  /// In en, this message translates to:
  /// **'Secure storage'**
  String get settingsAboutSecureStorageLabel;

  /// No description provided for @settingsAboutSecureStorageProbing.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get settingsAboutSecureStorageProbing;

  /// No description provided for @settingsAboutSecureStorageAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available ({backend})'**
  String settingsAboutSecureStorageAvailable(String backend);

  /// No description provided for @settingsAboutSecureStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: {reason}'**
  String settingsAboutSecureStorageUnavailable(String reason);

  /// No description provided for @settingsAboutLicensesButton.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get settingsAboutLicensesButton;

  /// No description provided for @settingsAboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'InkFrame is released under the MIT license. Bundled components keep their own licenses: libmpv and FFmpeg (LGPL-2.1), PostgreSQL (PostgreSQL License), and the Cormorant Garamond and JetBrains Mono fonts (SIL OFL 1.1).'**
  String get settingsAboutLegalese;

  /// No description provided for @settingsAboutUpdateCheckButton.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsAboutUpdateCheckButton;

  /// No description provided for @settingsAboutUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get settingsAboutUpdateChecking;

  /// No description provided for @settingsAboutUpdateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get settingsAboutUpdateUpToDate;

  /// No description provided for @settingsAboutUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version {version} available'**
  String settingsAboutUpdateAvailable(String version);

  /// No description provided for @settingsAboutUpdateViewRelease.
  ///
  /// In en, this message translates to:
  /// **'View release'**
  String get settingsAboutUpdateViewRelease;

  /// No description provided for @settingsAboutUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get settingsAboutUpdateCheckFailed;

  /// No description provided for @settingsAboutUpdateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the release page'**
  String get settingsAboutUpdateOpenFailed;

  /// No description provided for @settingsAboutUpdateAutoCheckLabel.
  ///
  /// In en, this message translates to:
  /// **'Check for updates at startup'**
  String get settingsAboutUpdateAutoCheckLabel;

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

  /// No description provided for @linkCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create link'**
  String get linkCreateFailed;

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

  /// No description provided for @nodesDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} node deleted} other{{count} nodes deleted}}'**
  String nodesDeleted(int count);

  /// No description provided for @nodeDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete node'**
  String get nodeDeleteFailed;

  /// No description provided for @nodeMoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to move node'**
  String get nodeMoveFailed;

  /// No description provided for @edgeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Link deleted'**
  String get edgeDeleted;

  /// No description provided for @undoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t undo'**
  String get undoFailed;

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

  /// No description provided for @inspectorInputsLabelCounted.
  ///
  /// In en, this message translates to:
  /// **'Inputs ({count}/{max})'**
  String inspectorInputsLabelCounted(int count, int max);

  /// No description provided for @inspectorInputsOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Exceeds provider limit ({max}); extra reference images are ignored'**
  String inspectorInputsOverLimit(int max);

  /// No description provided for @inspectorPresetsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save preset'**
  String get inspectorPresetsSaveFailed;

  /// No description provided for @inspectorCharactersImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import character'**
  String get inspectorCharactersImportFailed;

  /// No description provided for @inspectorCharactersLabel.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get inspectorCharactersLabel;

  /// No description provided for @inspectorCharactersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No characters yet'**
  String get inspectorCharactersEmpty;

  /// No description provided for @inspectorCharactersUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This model ignores reference images'**
  String get inspectorCharactersUnsupported;

  /// No description provided for @inspectorCharactersSaveFromReference.
  ///
  /// In en, this message translates to:
  /// **'Save reference as character'**
  String get inspectorCharactersSaveFromReference;

  /// No description provided for @inspectorCharactersImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import image file'**
  String get inspectorCharactersImportFile;

  /// No description provided for @inspectorCharactersDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New character'**
  String get inspectorCharactersDialogTitle;

  /// No description provided for @inspectorCharactersNameHint.
  ///
  /// In en, this message translates to:
  /// **'Character name'**
  String get inspectorCharactersNameHint;

  /// No description provided for @inspectorCharactersSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get inspectorCharactersSave;

  /// No description provided for @inspectorPresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt presets'**
  String get inspectorPresetsLabel;

  /// No description provided for @inspectorPresetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No presets yet'**
  String get inspectorPresetsEmpty;

  /// No description provided for @inspectorPresetsSaveCurrent.
  ///
  /// In en, this message translates to:
  /// **'Save current as preset'**
  String get inspectorPresetsSaveCurrent;

  /// No description provided for @inspectorPresetsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New preset'**
  String get inspectorPresetsDialogTitle;

  /// No description provided for @inspectorPresetsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get inspectorPresetsNameHint;

  /// No description provided for @batchResultsLabel.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get batchResultsLabel;

  /// No description provided for @inspectorResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get inspectorResultTitle;

  /// No description provided for @inspectorShotTitle.
  ///
  /// In en, this message translates to:
  /// **'Shot'**
  String get inspectorShotTitle;

  /// No description provided for @inspectorShotNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Shot notes'**
  String get inspectorShotNotesLabel;

  /// No description provided for @inspectorShotNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Describe this shot (camera, action, mood)...'**
  String get inspectorShotNotesHint;

  /// No description provided for @inspectorShotGenerateImage.
  ///
  /// In en, this message translates to:
  /// **'Generate image from notes'**
  String get inspectorShotGenerateImage;

  /// No description provided for @inspectorShotLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Image node added, but linking failed'**
  String get inspectorShotLinkFailed;

  /// No description provided for @canvasAddImageNode.
  ///
  /// In en, this message translates to:
  /// **'Add image node'**
  String get canvasAddImageNode;

  /// No description provided for @canvasAddVideoNode.
  ///
  /// In en, this message translates to:
  /// **'Add video node'**
  String get canvasAddVideoNode;

  /// No description provided for @canvasAddShotNode.
  ///
  /// In en, this message translates to:
  /// **'Add shot node'**
  String get canvasAddShotNode;

  /// No description provided for @canvasAddNodeTooltip.
  ///
  /// In en, this message translates to:
  /// **'New node'**
  String get canvasAddNodeTooltip;

  /// No description provided for @canvasAddNodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add node'**
  String get canvasAddNodeFailed;

  /// No description provided for @inspectorVideoPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Video prompt'**
  String get inspectorVideoPromptLabel;

  /// No description provided for @inspectorVideoDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (seconds)'**
  String get inspectorVideoDurationLabel;

  /// No description provided for @inspectorVideoDurationOption.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String inspectorVideoDurationOption(int seconds);

  /// No description provided for @inspectorVideoCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera movement'**
  String get inspectorVideoCameraLabel;

  /// No description provided for @cameraStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get cameraStatic;

  /// No description provided for @cameraPushIn.
  ///
  /// In en, this message translates to:
  /// **'Push in'**
  String get cameraPushIn;

  /// No description provided for @cameraPullOut.
  ///
  /// In en, this message translates to:
  /// **'Pull out'**
  String get cameraPullOut;

  /// No description provided for @cameraPanLeft.
  ///
  /// In en, this message translates to:
  /// **'Pan left'**
  String get cameraPanLeft;

  /// No description provided for @cameraPanRight.
  ///
  /// In en, this message translates to:
  /// **'Pan right'**
  String get cameraPanRight;

  /// No description provided for @cameraTiltUp.
  ///
  /// In en, this message translates to:
  /// **'Tilt up'**
  String get cameraTiltUp;

  /// No description provided for @cameraTiltDown.
  ///
  /// In en, this message translates to:
  /// **'Tilt down'**
  String get cameraTiltDown;

  /// No description provided for @cameraOrbit.
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get cameraOrbit;

  /// No description provided for @cameraHandheld.
  ///
  /// In en, this message translates to:
  /// **'Handheld'**
  String get cameraHandheld;

  /// No description provided for @inspectorVideoModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Mode: auto-detected from inputs'**
  String get inspectorVideoModeAuto;

  /// No description provided for @inspectorVideoGenerateDisabledEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt required'**
  String get inspectorVideoGenerateDisabledEmptyPrompt;

  /// No description provided for @inspectorVideoGenerateDisabledNoKey.
  ///
  /// In en, this message translates to:
  /// **'API key required in Settings'**
  String get inspectorVideoGenerateDisabledNoKey;

  /// No description provided for @inspectorVideoGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate video'**
  String get inspectorVideoGenerate;

  /// Video lightbox close tooltip
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get lightboxClose;

  /// Video lightbox play/pause tooltip
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get lightboxPlayPause;

  /// Fallback workspace name shown before the user names their studio
  ///
  /// In en, this message translates to:
  /// **'My Studio'**
  String get studioDefaultName;

  /// No description provided for @studioRecentProjects.
  ///
  /// In en, this message translates to:
  /// **'Recent Projects'**
  String get studioRecentProjects;

  /// No description provided for @studioNewProject.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get studioNewProject;

  /// No description provided for @studioLibrary.
  ///
  /// In en, this message translates to:
  /// **'LIBRARY'**
  String get studioLibrary;

  /// No description provided for @studioLibraryProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get studioLibraryProjects;

  /// No description provided for @studioBreadcrumbAll.
  ///
  /// In en, this message translates to:
  /// **'All Projects'**
  String get studioBreadcrumbAll;

  /// No description provided for @studioEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get studioEmptyTitle;

  /// No description provided for @studioEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first project to start building storyboards.'**
  String get studioEmptySubtitle;

  /// No description provided for @studioErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load projects'**
  String get studioErrorTitle;

  /// No description provided for @studioErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get studioErrorRetry;

  /// No description provided for @studioOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get studioOpenSettings;

  /// No description provided for @studioNewProjectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create new project'**
  String get studioNewProjectDialogTitle;

  /// No description provided for @studioNewProjectNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get studioNewProjectNameLabel;

  /// No description provided for @studioNewProjectNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sunset Heist'**
  String get studioNewProjectNameHint;

  /// No description provided for @studioNewProjectErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Project name is required'**
  String get studioNewProjectErrorEmpty;

  /// No description provided for @studioNewProjectErrorTooLong.
  ///
  /// In en, this message translates to:
  /// **'Project name must be 60 characters or fewer'**
  String get studioNewProjectErrorTooLong;

  /// No description provided for @studioNewProjectErrorDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A project with this name already exists'**
  String get studioNewProjectErrorDuplicate;

  /// No description provided for @studioNewProjectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create project'**
  String get studioNewProjectFailed;

  /// No description provided for @studioCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get studioCreate;

  /// No description provided for @studioRenameProject.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get studioRenameProject;

  /// No description provided for @studioRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get studioRename;

  /// No description provided for @studioRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename project'**
  String get studioRenameFailed;

  /// No description provided for @studioDeleteProject.
  ///
  /// In en, this message translates to:
  /// **'Delete project'**
  String get studioDeleteProject;

  /// No description provided for @studioDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get studioDelete;

  /// No description provided for @studioDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete project?'**
  String get studioDeleteConfirmTitle;

  /// No description provided for @studioDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The project and its canvases will be moved out of your library.'**
  String get studioDeleteConfirmBody;

  /// No description provided for @studioDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete project'**
  String get studioDeleteFailed;

  /// No description provided for @studioManageCanvases.
  ///
  /// In en, this message translates to:
  /// **'Manage canvases'**
  String get studioManageCanvases;

  /// No description provided for @studioRenameCanvas.
  ///
  /// In en, this message translates to:
  /// **'Rename canvas'**
  String get studioRenameCanvas;

  /// No description provided for @studioRenameCanvasFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename canvas'**
  String get studioRenameCanvasFailed;

  /// No description provided for @studioCanvasDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete canvas?'**
  String get studioCanvasDeleteConfirmTitle;

  /// No description provided for @studioCanvasDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The canvas will be removed from this project.'**
  String get studioCanvasDeleteConfirmBody;

  /// No description provided for @studioDeleteCanvasFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete canvas'**
  String get studioDeleteCanvasFailed;

  /// No description provided for @studioNoCanvases.
  ///
  /// In en, this message translates to:
  /// **'No canvases in this project'**
  String get studioNoCanvases;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @studioProjectMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Project options'**
  String get studioProjectMenuTooltip;

  /// Project card meta line: real creation month + canvas count
  ///
  /// In en, this message translates to:
  /// **'{date} · {count, plural, =1{1 canvas} other{{count} canvases}}'**
  String studioProjectMetaLine(DateTime date, int count);

  /// No description provided for @canvasDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Untitled Canvas'**
  String get canvasDefaultName;

  /// No description provided for @studioOpenCanvasFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open canvas'**
  String get studioOpenCanvasFailed;

  /// No description provided for @studioNoKeyBannerText.
  ///
  /// In en, this message translates to:
  /// **'No provider API key configured — generation needs one.'**
  String get studioNoKeyBannerText;

  /// No description provided for @studioNoKeyBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Configure in Settings'**
  String get studioNoKeyBannerAction;

  /// No description provided for @studioCreateSampleProject.
  ///
  /// In en, this message translates to:
  /// **'Create sample project'**
  String get studioCreateSampleProject;

  /// No description provided for @studioCreateSampleFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create sample project'**
  String get studioCreateSampleFailed;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to InkFrame'**
  String get onboardingTitle;

  /// Onboarding wizard progress indicator
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepIndicator(int current, int total);

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start empty'**
  String get onboardingStartEmpty;

  /// No description provided for @onboardingKeysConsoleHint.
  ///
  /// In en, this message translates to:
  /// **'Get an API key from your provider\'s console and paste it above — you can also add or change keys later in Settings.'**
  String get onboardingKeysConsoleHint;

  /// No description provided for @onboardingStepSampleTitle.
  ///
  /// In en, this message translates to:
  /// **'Start creating'**
  String get onboardingStepSampleTitle;

  /// No description provided for @onboardingStepSampleBody.
  ///
  /// In en, this message translates to:
  /// **'Create a sample project to explore the canvas, or start from an empty studio.'**
  String get onboardingStepSampleBody;

  /// No description provided for @canvasRenderQueue.
  ///
  /// In en, this message translates to:
  /// **'Render Queue'**
  String get canvasRenderQueue;

  /// No description provided for @canvasRenderQueueExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand render queue'**
  String get canvasRenderQueueExpand;

  /// No description provided for @canvasRenderQueueCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse render queue'**
  String get canvasRenderQueueCollapse;

  /// No description provided for @canvasNodeTypeCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get canvasNodeTypeCharacter;

  /// No description provided for @canvasNodeTypeScene.
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get canvasNodeTypeScene;

  /// No description provided for @canvasNodeTypeCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get canvasNodeTypeCamera;

  /// No description provided for @canvasNodeTypeProp.
  ///
  /// In en, this message translates to:
  /// **'Prop'**
  String get canvasNodeTypeProp;

  /// No description provided for @canvasNodeTypeShot.
  ///
  /// In en, this message translates to:
  /// **'Shot'**
  String get canvasNodeTypeShot;

  /// No description provided for @canvasNodeTypeImageGen.
  ///
  /// In en, this message translates to:
  /// **'Image Gen'**
  String get canvasNodeTypeImageGen;

  /// No description provided for @canvasBreadcrumbProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get canvasBreadcrumbProject;

  /// No description provided for @canvasBreadcrumbCanvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get canvasBreadcrumbCanvas;

  /// Canvas top chrome — labeled affordance to return to the Studio home
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get canvasBackToStudio;

  /// No description provided for @canvasEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This canvas is empty'**
  String get canvasEmptyTitle;

  /// No description provided for @canvasEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first node to start storyboarding.'**
  String get canvasEmptySubtitle;

  /// No description provided for @canvasEmptyAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image node'**
  String get canvasEmptyAddImage;

  /// No description provided for @canvasEmptyAddVideo.
  ///
  /// In en, this message translates to:
  /// **'Add video node'**
  String get canvasEmptyAddVideo;

  /// No description provided for @canvasEmptyAddShot.
  ///
  /// In en, this message translates to:
  /// **'Add shot node'**
  String get canvasEmptyAddShot;

  /// No description provided for @canvasSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String canvasSelectionCount(int count);

  /// No description provided for @canvasRenderQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active renders'**
  String get canvasRenderQueueEmpty;

  /// No description provided for @canvasRenderQueueStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get canvasRenderQueueStatusQueued;

  /// Render queue — tooltip/label on the per-job cancel control that stops a running or queued generation
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get canvasRenderQueueCancel;

  /// Render queue — section header above the recently-failed jobs list
  ///
  /// In en, this message translates to:
  /// **'Recent failures'**
  String get canvasRenderQueueFailures;

  /// Window chrome minimize button a11y label
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowMinimize;

  /// Window chrome maximize/restore button a11y label
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get windowMaximize;

  /// Window chrome close button a11y label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get windowClose;

  /// No description provided for @laneAdd.
  ///
  /// In en, this message translates to:
  /// **'Add lane'**
  String get laneAdd;

  /// No description provided for @laneNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New lane'**
  String get laneNewTitle;

  /// No description provided for @laneEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit lane'**
  String get laneEditTitle;

  /// No description provided for @laneNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get laneNameLabel;

  /// No description provided for @laneNameHint.
  ///
  /// In en, this message translates to:
  /// **'Lane name'**
  String get laneNameHint;

  /// No description provided for @laneStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style description'**
  String get laneStyleLabel;

  /// No description provided for @laneStyleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. warm sunset lighting, candlelit'**
  String get laneStyleHint;

  /// No description provided for @laneTintLabel.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get laneTintLabel;

  /// No description provided for @laneTintAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get laneTintAuto;

  /// No description provided for @laneDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete lane'**
  String get laneDelete;

  /// No description provided for @laneDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this lane?'**
  String get laneDeleteConfirmTitle;

  /// No description provided for @laneDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Nodes in this lane keep their position but lose the lane style.'**
  String get laneDeleteConfirmBody;

  /// No description provided for @laneDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get laneDialogSave;

  /// No description provided for @laneDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get laneDialogCancel;

  /// No description provided for @laneDirectionToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle lane direction'**
  String get laneDirectionToggle;

  /// No description provided for @laneUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled lane'**
  String get laneUntitled;

  /// No description provided for @laneCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create lane'**
  String get laneCreateFailed;

  /// No description provided for @laneUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update lane'**
  String get laneUpdateFailed;

  /// No description provided for @laneDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete lane'**
  String get laneDeleteFailed;

  /// No description provided for @laneCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse lane'**
  String get laneCollapse;

  /// No description provided for @laneExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand lane'**
  String get laneExpand;

  /// No description provided for @inspectorPromptPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Final prompt preview'**
  String get inspectorPromptPreviewLabel;

  /// No description provided for @inspectorIgnoreLaneStyle.
  ///
  /// In en, this message translates to:
  /// **'Ignore lane style'**
  String get inspectorIgnoreLaneStyle;

  /// No description provided for @baseStyleEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Base style'**
  String get baseStyleEditTooltip;

  /// No description provided for @baseStyleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Project base style'**
  String get baseStyleEditTitle;

  /// No description provided for @baseStylePrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'Prefix (prepended to every prompt)'**
  String get baseStylePrefixLabel;

  /// No description provided for @baseStylePrefixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. cinematic film still'**
  String get baseStylePrefixHint;

  /// No description provided for @baseStyleSuffixLabel.
  ///
  /// In en, this message translates to:
  /// **'Suffix (appended to every prompt)'**
  String get baseStyleSuffixLabel;

  /// No description provided for @baseStyleSuffixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 8k, highly detailed'**
  String get baseStyleSuffixHint;

  /// No description provided for @baseStylePresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get baseStylePresetsLabel;

  /// No description provided for @baseStylePresetCinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get baseStylePresetCinematic;

  /// No description provided for @baseStylePresetAnime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get baseStylePresetAnime;

  /// No description provided for @baseStylePresetGhibli.
  ///
  /// In en, this message translates to:
  /// **'Ghibli'**
  String get baseStylePresetGhibli;

  /// No description provided for @baseStylePresetCyberpunk.
  ///
  /// In en, this message translates to:
  /// **'Cyberpunk'**
  String get baseStylePresetCyberpunk;

  /// No description provided for @baseStylePresetInkwash.
  ///
  /// In en, this message translates to:
  /// **'Ink wash'**
  String get baseStylePresetInkwash;

  /// No description provided for @baseStylePresetPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photographic'**
  String get baseStylePresetPhoto;

  /// No description provided for @baseStylePreset3d.
  ///
  /// In en, this message translates to:
  /// **'3D animation'**
  String get baseStylePreset3d;

  /// No description provided for @baseStyleUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update base style'**
  String get baseStyleUpdateFailed;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @galleryEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryEntryLabel;

  /// Gallery top chrome breadcrumb
  ///
  /// In en, this message translates to:
  /// **'{projectName} / Gallery'**
  String galleryBreadcrumb(String projectName);

  /// No description provided for @galleryBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to studio'**
  String get galleryBackTooltip;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No generated assets yet'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Images and videos generated on this project\'s canvases will appear here.'**
  String get galleryEmptySubtitle;

  /// No description provided for @galleryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load gallery'**
  String get galleryLoadFailed;

  /// No description provided for @galleryKindImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get galleryKindImage;

  /// No description provided for @galleryKindVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get galleryKindVideo;

  /// No description provided for @exportVideoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export video'**
  String get exportVideoTooltip;

  /// No description provided for @exportVideoDisabledTooltip.
  ///
  /// In en, this message translates to:
  /// **'No video results on this canvas yet'**
  String get exportVideoDisabledTooltip;

  /// No description provided for @exportVideoDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export video'**
  String get exportVideoDialogTitle;

  /// No description provided for @exportVideoDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Selected clips are joined in list order.'**
  String get exportVideoDialogHint;

  /// No description provided for @exportVideoOutputNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Output file name (optional)'**
  String get exportVideoOutputNameLabel;

  /// No description provided for @exportVideoOutputNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for a timestamped name'**
  String get exportVideoOutputNameHint;

  /// No description provided for @exportVideoInvalidName.
  ///
  /// In en, this message translates to:
  /// **'File name cannot contain \\ / : * ? \" < > |, \'..\', control characters, or reserved device names'**
  String get exportVideoInvalidName;

  /// No description provided for @exportVideoMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get exportVideoMoveUp;

  /// No description provided for @exportVideoMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get exportVideoMoveDown;

  /// No description provided for @exportVideoStart.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportVideoStart;

  /// Snackbar after a successful video export; path is project-relative
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String exportVideoSuccess(String path);

  /// No description provided for @exportVideoCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get exportVideoCopyPath;

  /// No description provided for @exportVideoPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied to clipboard'**
  String get exportVideoPathCopied;

  /// No description provided for @exportVideoFfmpegMissing.
  ///
  /// In en, this message translates to:
  /// **'ffmpeg not found — install it and retry (set the INKFRAME_FFMPEG environment variable to use a custom location)'**
  String get exportVideoFfmpegMissing;

  /// Full-screen startup failure surface title shown when the embedded database fails to start or migrate
  ///
  /// In en, this message translates to:
  /// **'InkFrame couldn\'t start'**
  String get startupErrorTitle;

  /// Startup failure surface body explaining the database boot failure and reassuring data durability
  ///
  /// In en, this message translates to:
  /// **'The embedded database failed to start or upgrade. Your projects on disk are safe. Review the logs below, then retry.'**
  String get startupErrorBody;

  /// Label above the log directory path on the startup failure surface
  ///
  /// In en, this message translates to:
  /// **'Log directory'**
  String get startupErrorLogPathLabel;

  /// Button that opens the log directory in the OS file browser from the startup failure surface
  ///
  /// In en, this message translates to:
  /// **'Open log directory'**
  String get startupErrorOpenLogDir;

  /// Tooltip / semantics label of the ⌘K chip that opens the command palette
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get commandPaletteTooltip;

  /// No description provided for @commandPaletteSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Type a command…'**
  String get commandPaletteSearchHint;

  /// No description provided for @commandPaletteNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching commands'**
  String get commandPaletteNoResults;

  /// Command palette action — leave canvas/gallery/settings and return to the Studio home
  ///
  /// In en, this message translates to:
  /// **'Back to Studio'**
  String get commandBackToStudio;
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

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

  /// No description provided for @generationQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Render Queue'**
  String get generationQueueTitle;

  /// No description provided for @generationQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active jobs'**
  String get generationQueueEmpty;

  /// No description provided for @generationQueueClearTerminated.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get generationQueueClearTerminated;

  /// No description provided for @generationQueueRemove.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get generationQueueRemove;

  /// No description provided for @generationQueueCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get generationQueueCancel;

  /// No description provided for @generationQueueRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get generationQueueRetry;

  /// No description provided for @generationStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get generationStatusQueued;

  /// No description provided for @generationStatusSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting'**
  String get generationStatusSubmitting;

  /// No description provided for @generationStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get generationStatusRunning;

  /// No description provided for @generationStatusSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get generationStatusSucceeded;

  /// No description provided for @generationStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get generationStatusFailed;

  /// No description provided for @generationStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get generationStatusCancelled;

  /// No description provided for @generationCountActive.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String generationCountActive(int count);

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

  /// No description provided for @canvasAddVideoNode.
  ///
  /// In en, this message translates to:
  /// **'Add video node'**
  String get canvasAddVideoNode;

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

  /// No description provided for @inspectorVideoModeT2v.
  ///
  /// In en, this message translates to:
  /// **'Text-to-video'**
  String get inspectorVideoModeT2v;

  /// No description provided for @inspectorVideoModeI2v.
  ///
  /// In en, this message translates to:
  /// **'Image-to-video'**
  String get inspectorVideoModeI2v;

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

  /// No description provided for @studioArchive.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVE'**
  String get studioArchive;

  /// No description provided for @studioArchivedProjects.
  ///
  /// In en, this message translates to:
  /// **'Archived Projects'**
  String get studioArchivedProjects;

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

  /// No description provided for @canvasInspectorTransform.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get canvasInspectorTransform;

  /// No description provided for @canvasInspectorCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get canvasInspectorCamera;

  /// No description provided for @canvasInspectorComposition.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get canvasInspectorComposition;

  /// No description provided for @canvasInspectorMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get canvasInspectorMetadata;

  /// No description provided for @canvasInspectorNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get canvasInspectorNotes;

  /// No description provided for @canvasInspectorAddAttribute.
  ///
  /// In en, this message translates to:
  /// **'Add Attribute'**
  String get canvasInspectorAddAttribute;

  /// No description provided for @canvasRenderQueue.
  ///
  /// In en, this message translates to:
  /// **'Render Queue'**
  String get canvasRenderQueue;

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

  /// No description provided for @canvasSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String canvasSelectionCount(int count);

  /// No description provided for @canvasInspectorKindCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera Node'**
  String get canvasInspectorKindCamera;

  /// No description provided for @canvasInspectorMockTitle.
  ///
  /// In en, this message translates to:
  /// **'Wide Shot'**
  String get canvasInspectorMockTitle;

  /// No description provided for @canvasInspectorMockId.
  ///
  /// In en, this message translates to:
  /// **'cam_0021'**
  String get canvasInspectorMockId;

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

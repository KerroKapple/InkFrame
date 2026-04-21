// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'InkFrame';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get errorInvalidKey =>
      'API key is invalid. Check your provider settings.';

  @override
  String get errorInsufficientBalance =>
      'Provider account has insufficient balance.';

  @override
  String get errorContentPolicy => 'The content policy rejected this request.';

  @override
  String get errorInvalidParameter =>
      'One or more request parameters are invalid.';

  @override
  String get errorNetworkTimeout => 'Network timed out. Please retry.';

  @override
  String get errorNetworkOffline =>
      'Network is offline. Check your connection.';

  @override
  String get errorProviderServer =>
      'The provider service is unavailable. Please retry.';

  @override
  String get errorProviderBusy => 'The provider is busy. Please retry shortly.';

  @override
  String get errorPollTimeout =>
      'Generation did not complete within the time limit.';

  @override
  String get errorDownloadFailed => 'Failed to download the generated asset.';

  @override
  String get errorLocalIO =>
      'Local disk I/O error. Check space and permissions.';

  @override
  String get errorCancelled => 'Cancelled by user.';

  @override
  String get errorCancelledOnExit =>
      'Cancelled because the application is exiting.';

  @override
  String get errorUnknown => 'An unknown error occurred.';

  @override
  String get canvasEmptyHint => 'Right-click or press + to add a node';

  @override
  String get canvasNodeDefaultLabel => 'New Node';

  @override
  String get canvasNodeImageType => 'Image';

  @override
  String get canvasAddNode => 'Add Node';

  @override
  String get canvasDeleteNode => 'Delete Node';

  @override
  String canvasNodesSelected(int count) {
    return '$count node(s) selected';
  }

  @override
  String get canvasNoCanvasOpen => 'No canvas is open';

  @override
  String get canvasCreateSampleCanvas => 'Create sample canvas';

  @override
  String get canvasLoadFailed => 'Failed to load canvas';

  @override
  String get canvasSampleProjectName => 'Sample Project';

  @override
  String get canvasSampleCanvasName => 'Canvas 1';

  @override
  String get inspectorTitle => 'Config';

  @override
  String get inspectorPromptLabel => 'Prompt';

  @override
  String get inspectorPromptHint => 'Describe the image you want...';

  @override
  String get inspectorProviderLabel => 'Provider';

  @override
  String get inspectorResolutionLabel => 'Resolution';

  @override
  String get inspectorGenerate => 'Generate';

  @override
  String get inspectorGenerateDisabledEmptyPrompt => 'Write a prompt first';

  @override
  String get inspectorGenerateDisabledNoKey => 'Configure API key in Settings';

  @override
  String get inspectorGenerateNotWiredYet =>
      'Generation wiring ships in the next slice';

  @override
  String get inspectorSelectSingleHint => 'Select a single config node to edit';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsApiKeysSection => 'API Keys';

  @override
  String get settingsApiKeysHint =>
      'Keys are stored in your system keychain. Nothing is sent off-device.';

  @override
  String get settingsApiKeyPlaceholder => 'sk-...';

  @override
  String get settingsApiKeySave => 'Save';

  @override
  String get settingsApiKeyClear => 'Clear';

  @override
  String get settingsApiKeySet => 'Set';

  @override
  String get settingsApiKeyNotSet => 'Not set';

  @override
  String get settingsApiKeySaved => 'Saved';

  @override
  String get settingsApiKeyCleared => 'Cleared';

  @override
  String get generationSuccess => 'Generated';

  @override
  String get generationFailure => 'Generation failed';

  @override
  String get generationMissingKey => 'API key is missing';

  @override
  String generationInvalidConfig(String reason) {
    return 'Invalid configuration: $reason';
  }

  @override
  String get generationProviderNotRegistered => 'Provider not registered';

  @override
  String get resultNodePending => 'Waiting for generation';

  @override
  String get resultNodeImageMissing => 'Image file missing';

  @override
  String get linkModeStart => 'Start link';

  @override
  String get linkModeHint =>
      'Tap a target node to link, or tap empty space to cancel';

  @override
  String get linkCreated => 'Link created';

  @override
  String get linkAlreadyExists => 'Link already exists';

  @override
  String get linkSelfNotAllowed => 'Cannot link a node to itself';

  @override
  String get nodeDelete => 'Delete node';

  @override
  String get nodeDeleted => 'Node deleted';

  @override
  String get nodeDeleteFailed => 'Failed to delete node';
}

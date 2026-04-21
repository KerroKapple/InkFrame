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
}

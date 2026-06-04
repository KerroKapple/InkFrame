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
  String get workspaceTitle => 'Workspace';

  @override
  String get workspaceHeroTagline => 'AI-driven storyboard desktop tool';

  @override
  String get workspaceHeroSubtitle =>
      'Runs locally with privacy control; integrates multiple model providers; one canvas stitches text, image and video';

  @override
  String get workspaceProjectsHeader => 'My Projects';

  @override
  String get workspaceProjectsEmpty =>
      'No projects yet. Tap the FAB to create your first one.';

  @override
  String get workspaceNewProject => 'New project';

  @override
  String get workspaceNewProjectHint => 'Project name';

  @override
  String get workspaceNewCanvas => 'New canvas';

  @override
  String get workspaceNewCanvasHint => 'Canvas name';

  @override
  String workspaceCanvasCount(int count) {
    return '$count canvas(es)';
  }

  @override
  String get workspaceOpenCanvas => 'Open';

  @override
  String get workspaceBackToWorkspace => 'Back to workspace';

  @override
  String get workspaceLoadError => 'Failed to load project list';

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
  String get inspectorStatusSubmitting => 'Submitting...';

  @override
  String get inspectorStatusRunning => 'Generating...';

  @override
  String inspectorStatusRunningWithProgress(int percent) {
    return 'Generating... $percent%';
  }

  @override
  String get inspectorStatusErrorTitle => 'Generation failed';

  @override
  String get inspectorRetry => 'Retry';

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
  String get settingsThemeSection => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeHighContrast => 'High contrast';

  @override
  String get settingsThemeTextScale => 'Text size';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageZh => '中文';

  @override
  String get settingsStorageSection => 'Storage';

  @override
  String get settingsStorageReadOnlyHint =>
      'Database location is fixed in this release. Changing it requires a migration not yet implemented.';

  @override
  String get settingsStorageDatabasePathLabel => 'Database directory';

  @override
  String get settingsStorageCopyPath => 'Copy path';

  @override
  String get settingsStoragePathCopied => 'Path copied to clipboard';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsAboutAppNameLabel => 'Application';

  @override
  String get settingsAboutVersionLabel => 'Version';

  @override
  String get settingsAboutSecureStorageLabel => 'Secure storage';

  @override
  String get settingsAboutSecureStorageProbing => 'Checking…';

  @override
  String settingsAboutSecureStorageAvailable(String backend) {
    return 'Available ($backend)';
  }

  @override
  String settingsAboutSecureStorageUnavailable(String reason) {
    return 'Unavailable: $reason';
  }

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
  String get generationQueueTitle => 'Render Queue';

  @override
  String get generationQueueEmpty => 'No active jobs';

  @override
  String get generationQueueClearTerminated => 'Clear completed';

  @override
  String get generationQueueRemove => 'Dismiss';

  @override
  String get generationQueueCancel => 'Cancel job';

  @override
  String get generationQueueRetry => 'Retry';

  @override
  String get generationStatusQueued => 'Queued';

  @override
  String get generationStatusSubmitting => 'Submitting';

  @override
  String get generationStatusRunning => 'Running';

  @override
  String get generationStatusSucceeded => 'Done';

  @override
  String get generationStatusFailed => 'Failed';

  @override
  String get generationStatusCancelled => 'Cancelled';

  @override
  String generationCountActive(int count) {
    return '$count active';
  }

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

  @override
  String get inspectorInputsLabel => 'Inputs';

  @override
  String get inspectorInputsEmpty => 'No input connections';

  @override
  String get inspectorRoleReference => 'Reference';

  @override
  String get inspectorRoleFirstFrame => 'First frame';

  @override
  String get inspectorRoleLastFrame => 'Last frame';

  @override
  String get inspectorRemoveInput => 'Remove input';

  @override
  String get canvasAddImageNode => 'Add image node';

  @override
  String get canvasAddVideoNode => 'Add video node';

  @override
  String get canvasAddNodeTooltip => 'New node';

  @override
  String get canvasAddNodeFailed => 'Failed to add node';

  @override
  String get inspectorVideoPromptLabel => 'Video prompt';

  @override
  String get inspectorVideoDurationLabel => 'Duration (seconds)';

  @override
  String inspectorVideoDurationOption(int seconds) {
    return '${seconds}s';
  }

  @override
  String get inspectorVideoCameraLabel => 'Camera movement';

  @override
  String get inspectorVideoModeAuto => 'Mode: auto-detected from inputs';

  @override
  String get inspectorVideoModeT2v => 'Text-to-video';

  @override
  String get inspectorVideoModeI2v => 'Image-to-video';

  @override
  String get inspectorVideoGenerateDisabledEmptyPrompt => 'Prompt required';

  @override
  String get inspectorVideoGenerateDisabledNoKey =>
      'API key required in Settings';

  @override
  String get inspectorVideoGenerate => 'Generate video';

  @override
  String get lightboxClose => 'Close';

  @override
  String get lightboxPlayPause => 'Play / Pause';

  @override
  String get lockTagline => 'A DESK FOR STORYBOARDERS';

  @override
  String get lockKeyPlaceholder => 'Paste provider key...';

  @override
  String get lockKeyHelpLine1 =>
      'Get your API key from your provider dashboard.';

  @override
  String get lockKeyHelpLine2 => 'We never store your key on our servers.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockKeyInvalid => 'Key invalid or network error. Try again.';

  @override
  String get studioRecentProjects => 'Recent Projects';

  @override
  String get studioNewProject => 'New Project';

  @override
  String get studioLibrary => 'LIBRARY';

  @override
  String get studioArchive => 'ARCHIVE';

  @override
  String get studioArchivedProjects => 'Archived Projects';

  @override
  String get studioBreadcrumbAll => 'All Projects';

  @override
  String get studioEmptyTitle => 'No projects yet';

  @override
  String get studioEmptySubtitle =>
      'Create your first project to start building storyboards.';

  @override
  String get studioErrorTitle => 'Failed to load projects';

  @override
  String get studioErrorRetry => 'Retry';

  @override
  String get studioOpenSettings => 'Open settings';

  @override
  String get studioNewProjectDialogTitle => 'Create new project';

  @override
  String get studioNewProjectNameLabel => 'Project name';

  @override
  String get studioNewProjectNameHint => 'e.g. Sunset Heist';

  @override
  String get studioNewProjectErrorEmpty => 'Project name is required';

  @override
  String get studioNewProjectErrorTooLong =>
      'Project name must be 60 characters or fewer';

  @override
  String get studioNewProjectErrorDuplicate =>
      'A project with this name already exists';

  @override
  String get studioNewProjectFailed => 'Failed to create project';

  @override
  String get studioCreate => 'Create';

  @override
  String get canvasDefaultName => 'Untitled Canvas';

  @override
  String get studioOpenCanvasFailed => 'Couldn\'t open canvas';

  @override
  String get studioNoKeyBannerText =>
      'No provider API key configured — generation needs one.';

  @override
  String get studioNoKeyBannerAction => 'Configure in Settings';

  @override
  String get canvasInspectorTransform => 'Transform';

  @override
  String get canvasInspectorCamera => 'Camera';

  @override
  String get canvasInspectorComposition => 'Composition';

  @override
  String get canvasInspectorMetadata => 'Metadata';

  @override
  String get canvasInspectorNotes => 'Notes';

  @override
  String get canvasInspectorAddAttribute => 'Add Attribute';

  @override
  String get canvasRenderQueue => 'Render Queue';

  @override
  String get canvasNodeTypeCharacter => 'Character';

  @override
  String get canvasNodeTypeScene => 'Scene';

  @override
  String get canvasNodeTypeCamera => 'Camera';

  @override
  String get canvasNodeTypeProp => 'Prop';

  @override
  String get canvasNodeTypeShot => 'Shot';

  @override
  String get canvasNodeTypeImageGen => 'Image Gen';

  @override
  String get canvasBreadcrumbProject => 'Project';

  @override
  String get canvasBreadcrumbCanvas => 'Canvas';

  @override
  String get canvasBackToStudio => 'Studio';

  @override
  String get canvasEmptyTitle => 'This canvas is empty';

  @override
  String get canvasEmptySubtitle =>
      'Add your first node to start storyboarding.';

  @override
  String get canvasEmptyAddImage => 'Add image node';

  @override
  String get canvasEmptyAddVideo => 'Add video node';

  @override
  String canvasSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get canvasInspectorKindCamera => 'Camera Node';

  @override
  String get canvasInspectorMockTitle => 'Wide Shot';

  @override
  String get canvasInspectorMockId => 'cam_0021';

  @override
  String get canvasRenderQueueEmpty => 'No active renders';

  @override
  String get canvasRenderQueueStatusQueued => 'Queued';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowClose => 'Close';
}

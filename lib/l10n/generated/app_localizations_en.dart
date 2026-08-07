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
  String get commonCancel => 'Cancel';

  @override
  String get errorInvalidKey =>
      'API key was rejected by the provider. Update it in Settings → API Keys.';

  @override
  String get errorInsufficientBalance =>
      'Provider account has insufficient balance.';

  @override
  String get errorContentPolicy =>
      'The provider\'s content policy rejected this prompt. Adjust the prompt and try again.';

  @override
  String get errorInvalidParameter =>
      'The provider rejected some generation settings. Adjust resolution, aspect ratio or duration and retry.';

  @override
  String get errorNetworkTimeout => 'Network timed out. Please retry.';

  @override
  String get errorNetworkOffline =>
      'Couldn\'t reach the provider. Check your network connection, then retry.';

  @override
  String get errorProviderServer =>
      'The provider service is unavailable. Please retry.';

  @override
  String get errorProviderBusy => 'The provider is busy. Please retry shortly.';

  @override
  String get errorProviderInvalidResponse =>
      'The provider returned an invalid or empty result.';

  @override
  String get errorPollTimeout =>
      'Generation did not complete within the time limit.';

  @override
  String get errorDownloadFailed =>
      'The generated file couldn\'t be downloaded. Check your connection and retry.';

  @override
  String get errorLocalIO =>
      'Local disk I/O error. Check space and permissions.';

  @override
  String get errorCancelled => 'Cancelled.';

  @override
  String get errorCancelledOnExit =>
      'Cancelled because the application is exiting.';

  @override
  String get errorUnknown => 'An unknown error occurred.';

  @override
  String get canvasNodeDefaultLabel => 'New Node';

  @override
  String get canvasNodeImageType => 'Image';

  @override
  String get canvasNodeTextType => 'Text';

  @override
  String get canvasNodeVideoType => 'Video';

  @override
  String get canvasNodeShotType => 'Shot';

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
  String get canvasSampleLaneLabel => 'Ink Style';

  @override
  String get canvasSampleLaneStylePrompt =>
      'traditional Chinese ink painting, soft brush strokes, misty atmosphere';

  @override
  String get canvasSampleNodeLabel => 'First Shot';

  @override
  String get canvasSampleNodePrompt =>
      'A lone boat drifting on a misty river at dawn, distant mountains fading into the fog';

  @override
  String get inspectorTitle => 'Config';

  @override
  String get inspectorPromptLabel => 'Prompt';

  @override
  String get inspectorPromptHint => 'Describe the image you want…';

  @override
  String get inspectorProviderLabel => 'Provider';

  @override
  String get inspectorResolutionLabel => 'Resolution';

  @override
  String get inspectorAspectRatioLabel => 'Aspect ratio';

  @override
  String get inspectorSeedLabel => 'Seed';

  @override
  String get inspectorSeedHint => 'Random';

  @override
  String get inspectorNegativePromptLabel => 'Negative prompt';

  @override
  String get inspectorNegativePromptHint => 'What to avoid';

  @override
  String get inspectorBatchLabel => 'Batch size';

  @override
  String inspectorEstimatedCost(String amount) {
    return 'Est. cost $amount';
  }

  @override
  String get inspectorGenerate => 'Generate';

  @override
  String get inspectorGenerateDisabledEmptyPrompt => 'Write a prompt first';

  @override
  String get inspectorGenerateDisabledNoKey => 'Configure API key in Settings';

  @override
  String get inspectorStatusSubmitting => 'Submitting…';

  @override
  String get inspectorStatusRunning => 'Generating…';

  @override
  String inspectorStatusRunningWithProgress(int percent) {
    return 'Generating… $percent%';
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
  String get settingsApiKeySavedUnverified =>
      'Saved. The key couldn\'t be verified right now (network or service issue) — it will be checked on first use.';

  @override
  String get settingsApiKeyRejected =>
      'The provider rejected this key. It was not saved.';

  @override
  String get settingsApiKeyCleared => 'Cleared';

  @override
  String get settingsCustomProvidersSection => 'Custom Providers';

  @override
  String get settingsCustomProvidersHint =>
      'OpenAI-compatible endpoints, stored in custom_providers.json. API keys stay in secure storage. Changes take effect after restart.';

  @override
  String get settingsCustomProvidersEmpty => 'No custom providers yet';

  @override
  String get settingsCustomProvidersAdd => 'Add provider';

  @override
  String get settingsCustomProvidersRestartNotice =>
      'Changes saved — restart InkFrame to apply';

  @override
  String get settingsCustomProviderAddTitle => 'Add custom provider';

  @override
  String get settingsCustomProviderEditTitle => 'Edit custom provider';

  @override
  String get settingsCustomProviderFieldId => 'ID';

  @override
  String get settingsCustomProviderFieldDisplayName => 'Display name';

  @override
  String get settingsCustomProviderFieldTemplate => 'Template';

  @override
  String get settingsCustomProviderFieldBaseUrl => 'Base URL';

  @override
  String get settingsCustomProviderFieldModelId => 'Model ID';

  @override
  String get settingsCustomProviderSave => 'Save';

  @override
  String get settingsCustomProviderErrorRequired => 'Required';

  @override
  String get settingsCustomProviderErrorInvalidId =>
      'Letters, digits, - and _ only; must start with a letter or digit';

  @override
  String get settingsCustomProviderErrorDuplicateId =>
      'This ID is already in use';

  @override
  String get settingsCustomProviderErrorReservedId =>
      'Conflicts with a built-in provider';

  @override
  String get settingsCustomProviderErrorInvalidBaseUrl =>
      'Absolute http(s) URL without query, fragment or credentials';

  @override
  String get settingsCustomProviderDeleteTitle => 'Delete provider?';

  @override
  String settingsCustomProviderDeleteBody(String name) {
    return '\"$name\" will be removed from the config file. Its API key in secure storage is not deleted.';
  }

  @override
  String get settingsCustomProviderDeleteConfirm => 'Delete';

  @override
  String get settingsCustomProviderSaveFailed =>
      'Couldn\'t save. If custom_providers.json is corrupted, fix or remove it and retry.';

  @override
  String get settingsThemeSection => 'Theme';

  @override
  String get settingsCanvasSection => 'Canvas';

  @override
  String get settingsCanvasEdgeColor => 'Connection line color';

  @override
  String get settingsCanvasCardColor => 'Card color';

  @override
  String get settingsCanvasColorDefault => 'Theme default';

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
  String get settingsBackupSection => 'Backups & restore';

  @override
  String get settingsBackupHint =>
      'Daily cold backups of your local database — the last 7 are kept. Restore replaces the database only — media files on disk stay as-is.';

  @override
  String get settingsBackupNow => 'Back up now';

  @override
  String get settingsBackupDone => 'Backup created';

  @override
  String get settingsBackupNoBinaries =>
      'Bundled PostgreSQL tools not found — reinstall InkFrame to restore them';

  @override
  String get settingsBackupFailed =>
      'Backup failed — see the log folder for details';

  @override
  String get settingsBackupsEmpty => 'No backups yet';

  @override
  String settingsBackupMetaLine(String size, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'yyyy-MM-dd HH:mm',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '$size · $dateString';
  }

  @override
  String get settingsBackupKindDaily => 'Daily';

  @override
  String get settingsBackupKindManual => 'Manual';

  @override
  String get settingsBackupKindPreRestore => 'Pre-restore';

  @override
  String get settingsRestore => 'Restore';

  @override
  String get restoreConfirmTitle => 'Restore from backup?';

  @override
  String restoreConfirmBody(String file, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'yyyy-MM-dd HH:mm',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return 'Replace current data with \"$file\" ($dateString)? We\'ll try to create a safety backup first. Running generations will be cancelled, and you\'ll be returned to the home screen. Media files on disk are not rolled back.';
  }

  @override
  String get restoreDone => 'Restore complete';

  @override
  String get restoreFailed => 'Restore failed — your data was not changed';

  @override
  String get restoreFailedCorrupt => 'Backup file failed verification';

  @override
  String get restoreFailedVersionNewer =>
      'This backup was made by a newer version of InkFrame';

  @override
  String get restoreAbortedPreBackup =>
      'Safety backup failed — restore cancelled';

  @override
  String get restoreInProgress => 'Restoring…';

  @override
  String get startupErrorRestoreLatest => 'Restore latest backup';

  @override
  String get settingsDiagnosticsSection => 'Diagnostics';

  @override
  String get settingsDiagnosticsHint =>
      'Logs and configuration for bug reports — API keys are never included.';

  @override
  String get settingsOpenLogDir => 'Open log folder';

  @override
  String get settingsExportDiagnostics => 'Export diagnostics…';

  @override
  String get settingsDiagnosticsExported => 'Diagnostics exported';

  @override
  String get settingsDiagnosticsExportFailed =>
      'Export failed — see the log folder for details';

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
  String get settingsAboutFfmpegLabel => 'Video export (ffmpeg)';

  @override
  String get settingsAboutFfmpegProbing => 'Checking…';

  @override
  String settingsAboutFfmpegAvailable(String path) {
    return 'Available ($path)';
  }

  @override
  String get settingsAboutFfmpegMissingWindows =>
      'Not found — video export is disabled. Install via winget (winget install ffmpeg), or set the INKFRAME_FFMPEG environment variable to a custom location';

  @override
  String get settingsAboutFfmpegMissingMac =>
      'Not found — video export is disabled. Install via Homebrew (brew install ffmpeg), or set the INKFRAME_FFMPEG environment variable to a custom location';

  @override
  String get settingsAboutLicensesButton => 'Open-source licenses';

  @override
  String get settingsAboutLegalese =>
      'InkFrame is released under the MIT license. Bundled components keep their own licenses: libmpv and FFmpeg (LGPL-2.1), PostgreSQL (PostgreSQL License), and the Cormorant Garamond and JetBrains Mono fonts (SIL OFL 1.1).';

  @override
  String get settingsAboutUpdateCheckButton => 'Check for updates';

  @override
  String get settingsAboutUpdateChecking => 'Checking for updates…';

  @override
  String get settingsAboutUpdateUpToDate => 'You\'re on the latest version';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'New version $version available';
  }

  @override
  String get settingsAboutUpdateViewRelease => 'View release';

  @override
  String get settingsAboutUpdateCheckFailed => 'Couldn\'t check for updates';

  @override
  String get settingsAboutUpdateOpenFailed => 'Couldn\'t open the release page';

  @override
  String get settingsAboutUpdateAutoCheckLabel =>
      'Check for updates at startup';

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
  String get linkCreateFailed => 'Failed to create link';

  @override
  String get nodeDelete => 'Delete node';

  @override
  String get nodeDeleted => 'Node deleted';

  @override
  String nodesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes deleted',
      one: '$count node deleted',
    );
    return '$_temp0';
  }

  @override
  String get nodeDeleteFailed => 'Failed to delete node';

  @override
  String get nodeMoveFailed => 'Failed to move node';

  @override
  String get edgeDeleted => 'Link deleted';

  @override
  String get undoFailed => 'Couldn\'t undo';

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
  String inspectorInputsLabelCounted(int count, int max) {
    return 'Inputs ($count/$max)';
  }

  @override
  String inspectorInputsOverLimit(int max) {
    return 'Exceeds provider limit ($max); extra reference images are ignored';
  }

  @override
  String get inspectorPresetsSaveFailed => 'Failed to save preset';

  @override
  String get inspectorCharactersImportFailed => 'Failed to import character';

  @override
  String get inspectorCharactersLabel => 'Characters';

  @override
  String get inspectorCharactersEmpty => 'No characters yet';

  @override
  String get inspectorCharactersUnsupported =>
      'This model ignores reference images';

  @override
  String get inspectorCharactersSaveFromReference =>
      'Save reference as character';

  @override
  String get inspectorCharactersImportFile => 'Import image file';

  @override
  String get inspectorCharactersDialogTitle => 'New character';

  @override
  String get inspectorCharactersNameHint => 'Character name';

  @override
  String get inspectorCharactersSave => 'Save';

  @override
  String get inspectorPresetsLabel => 'Prompt presets';

  @override
  String get inspectorPresetsEmpty => 'No presets yet';

  @override
  String get inspectorPresetsSaveCurrent => 'Save current as preset';

  @override
  String get inspectorPresetsDialogTitle => 'New preset';

  @override
  String get inspectorPresetsNameHint => 'Preset name';

  @override
  String get batchResultsLabel => 'Variants';

  @override
  String get inspectorResultTitle => 'Result';

  @override
  String get inspectorShotTitle => 'Shot';

  @override
  String get inspectorShotNotesLabel => 'Shot notes';

  @override
  String get inspectorShotNotesHint =>
      'Describe this shot (camera, action, mood)…';

  @override
  String get inspectorShotGenerateImage => 'Generate image from notes';

  @override
  String get inspectorShotLinkFailed => 'Image node added, but linking failed';

  @override
  String get inspectorShotDurationLabel => 'Intended duration';

  @override
  String get inspectorShotCameraLabel => 'Intended camera movement';

  @override
  String get inspectorShotParamUnset => 'Not set';

  @override
  String get inspectorShotParamHint =>
      'Recorded as intent — the provider you pick when generating decides what is actually supported.';

  @override
  String get canvasAddImageNode => 'Add image node';

  @override
  String get canvasAddVideoNode => 'Add video node';

  @override
  String get canvasAddShotNode => 'Add shot node';

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
  String get cameraStatic => 'Static';

  @override
  String get cameraPushIn => 'Push in';

  @override
  String get cameraPullOut => 'Pull out';

  @override
  String get cameraPanLeft => 'Pan left';

  @override
  String get cameraPanRight => 'Pan right';

  @override
  String get cameraTiltUp => 'Tilt up';

  @override
  String get cameraTiltDown => 'Tilt down';

  @override
  String get cameraOrbit => 'Orbit';

  @override
  String get cameraHandheld => 'Handheld';

  @override
  String get inspectorVideoModeAuto => 'Mode: auto-detected from inputs';

  @override
  String get inspectorVideoGenerateDisabledEmptyPrompt =>
      'Write a prompt first';

  @override
  String get inspectorVideoGenerateDisabledNoKey =>
      'Configure API key in Settings';

  @override
  String get inspectorVideoGenerate => 'Generate video';

  @override
  String get lightboxClose => 'Close';

  @override
  String get lightboxPlayPause => 'Play / Pause';

  @override
  String get studioDefaultName => 'My Studio';

  @override
  String get studioRecentProjects => 'Recent Projects';

  @override
  String get studioNewProject => 'New Project';

  @override
  String get studioLibrary => 'LIBRARY';

  @override
  String get studioLibraryProjects => 'Projects';

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
  String get studioRenameProject => 'Rename project';

  @override
  String get studioRename => 'Rename';

  @override
  String get studioRenameFailed => 'Failed to rename project';

  @override
  String get studioDeleteProject => 'Delete project';

  @override
  String get studioDelete => 'Delete';

  @override
  String get studioDeleteConfirmTitle => 'Delete project?';

  @override
  String get studioDeleteConfirmBody =>
      'The project and its canvases will be moved out of your library.';

  @override
  String get studioDeleteFailed => 'Failed to delete project';

  @override
  String get studioManageCanvases => 'Manage canvases';

  @override
  String get studioExportProject => 'Export project…';

  @override
  String get studioExportProjectDone => 'Project exported';

  @override
  String get studioExportProjectFailed => 'Failed to export project';

  @override
  String get studioImportProject => 'Import project…';

  @override
  String get importInProgress => 'Importing…';

  @override
  String get importDone => 'Project imported';

  @override
  String get importFailedFormat => 'Not an InkFrame project archive';

  @override
  String get importFailedVersionNewer =>
      'This archive was made by a newer version of InkFrame';

  @override
  String get importFailedCorrupt => 'Archive failed verification';

  @override
  String get importFailed => 'Import failed';

  @override
  String get studioTrash => 'Trash';

  @override
  String get studioTrashEmpty => 'Trash is empty';

  @override
  String get studioRestore => 'Restore';

  @override
  String studioTrashDeletedAt(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'yyyy-MM-dd HH:mm',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return 'Deleted $dateString';
  }

  @override
  String get studioRestoreFailed => 'Couldn\'t restore';

  @override
  String get studioRenameCanvas => 'Rename canvas';

  @override
  String get studioRenameCanvasFailed => 'Failed to rename canvas';

  @override
  String get studioCanvasDeleteConfirmTitle => 'Delete canvas?';

  @override
  String get studioCanvasDeleteConfirmBody =>
      'The canvas will be removed from this project.';

  @override
  String get studioDeleteCanvasFailed => 'Failed to delete canvas';

  @override
  String get studioNoCanvases => 'No canvases in this project';

  @override
  String get commonClose => 'Close';

  @override
  String get commonUndo => 'Undo';

  @override
  String get studioProjectMenuTooltip => 'Project options';

  @override
  String studioProjectMetaLine(DateTime date, int count) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMM(localeName);
    final String dateString = dateDateFormat.format(date);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canvases',
      one: '1 canvas',
    );
    return '$dateString · $_temp0';
  }

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
  String get studioCreateSampleProject => 'Create sample project';

  @override
  String get studioCreateSampleFailed => 'Couldn\'t create sample project';

  @override
  String get onboardingTitle => 'Welcome to InkFrame';

  @override
  String onboardingStepIndicator(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStartEmpty => 'Start empty';

  @override
  String get onboardingKeysConsoleHint =>
      'Get an API key from your provider\'s console and paste it above — you can also add or change keys later in Settings.';

  @override
  String get onboardingStepSampleTitle => 'Start creating';

  @override
  String get onboardingStepSampleBody =>
      'Create a sample project to explore the canvas, or start from an empty Studio.';

  @override
  String get canvasRenderQueue => 'Render Queue';

  @override
  String get canvasRenderQueueExpand => 'Expand render queue';

  @override
  String get canvasRenderQueueCollapse => 'Collapse render queue';

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
  String get canvasEmptyAddShot => 'Add shot node';

  @override
  String canvasSelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get canvasRenderQueueEmpty => 'No active renders';

  @override
  String get canvasRenderQueueStatusQueued => 'Queued';

  @override
  String get canvasRenderQueueCancel => 'Cancel job';

  @override
  String get canvasRenderQueueFailures => 'Recent failures';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowClose => 'Close';

  @override
  String get laneAdd => 'Add lane';

  @override
  String get laneNewTitle => 'New lane';

  @override
  String get laneEditTitle => 'Edit lane';

  @override
  String get laneNameLabel => 'Name';

  @override
  String get laneNameHint => 'Lane name';

  @override
  String get laneStyleLabel => 'Style description';

  @override
  String get laneStyleHint => 'e.g. warm sunset lighting, candlelit';

  @override
  String get laneTintLabel => 'Background color';

  @override
  String get laneTintAuto => 'Auto';

  @override
  String get laneDelete => 'Delete lane';

  @override
  String get laneDeleteConfirmTitle => 'Delete this lane?';

  @override
  String get laneDeleteConfirmBody =>
      'Nodes in this lane keep their position but lose the lane style.';

  @override
  String get laneDialogSave => 'Save';

  @override
  String get laneDialogCancel => 'Cancel';

  @override
  String get laneDirectionToggle => 'Toggle lane direction';

  @override
  String get laneUntitled => 'Untitled lane';

  @override
  String get laneCreateFailed => 'Failed to create lane';

  @override
  String get laneUpdateFailed => 'Failed to update lane';

  @override
  String get laneDeleteFailed => 'Failed to delete lane';

  @override
  String get laneCollapse => 'Collapse lane';

  @override
  String get laneExpand => 'Expand lane';

  @override
  String get inspectorPromptPreviewLabel => 'Final prompt preview';

  @override
  String get inspectorIgnoreLaneStyle => 'Ignore lane style';

  @override
  String get baseStyleEditTooltip => 'Base style';

  @override
  String get baseStyleEditTitle => 'Project base style';

  @override
  String get baseStylePrefixLabel => 'Prefix (prepended to every prompt)';

  @override
  String get baseStylePrefixHint => 'e.g. cinematic film still';

  @override
  String get baseStyleSuffixLabel => 'Suffix (appended to every prompt)';

  @override
  String get baseStyleSuffixHint => 'e.g. 8k, highly detailed';

  @override
  String get baseStylePresetsLabel => 'Presets';

  @override
  String get baseStylePresetCinematic => 'Cinematic';

  @override
  String get baseStylePresetAnime => 'Anime';

  @override
  String get baseStylePresetGhibli => 'Ghibli';

  @override
  String get baseStylePresetCyberpunk => 'Cyberpunk';

  @override
  String get baseStylePresetInkwash => 'Ink wash';

  @override
  String get baseStylePresetPhoto => 'Photographic';

  @override
  String get baseStylePreset3d => '3D animation';

  @override
  String get baseStyleUpdateFailed => 'Failed to update base style';

  @override
  String get commonRetry => 'Retry';

  @override
  String get galleryEntryLabel => 'Gallery';

  @override
  String galleryBreadcrumb(String projectName) {
    return '$projectName / Gallery';
  }

  @override
  String get galleryBackTooltip => 'Back to Studio';

  @override
  String get galleryEmptyTitle => 'No generated assets yet';

  @override
  String get galleryEmptySubtitle =>
      'Images and videos generated on this project\'s canvases will appear here.';

  @override
  String get galleryLoadFailed => 'Failed to load gallery';

  @override
  String get galleryFilterAll => 'All';

  @override
  String get galleryFilterCanvasAll => 'All canvases';

  @override
  String get gallerySearchHint => 'Search canvas name…';

  @override
  String get galleryFilterClear => 'Clear filters';

  @override
  String get galleryFilterNoMatches => 'No results match the current filters';

  @override
  String get gallerySaveAsCharacter => 'Save as character';

  @override
  String get gallerySavedAsCharacter => 'Character saved';

  @override
  String get galleryKindImage => 'Image';

  @override
  String get galleryKindVideo => 'Video';

  @override
  String get showcaseEntryLabel => 'Built-in samples';

  @override
  String get showcaseTitle => 'Built-in image samples';

  @override
  String get showcaseSubtitle =>
      'AI-generated sample images bundled with the app for offline preview. They are not project generation records and need no API key.';

  @override
  String get showcaseBackTooltip => 'Back to Studio';

  @override
  String get showcaseSquareTitle => 'Mountain study';

  @override
  String get showcaseSquareMeta => '1:1 · Ink wash';

  @override
  String get showcaseWideTitle => 'Storyboard establishing shot';

  @override
  String get showcaseWideMeta => '16:9 · Ink wash';

  @override
  String get exportVideoTooltip => 'Export video';

  @override
  String get exportVideoDisabledTooltip =>
      'No video results on this canvas yet';

  @override
  String get exportVideoDialogTitle => 'Export video';

  @override
  String get exportVideoDialogHint =>
      'Selected clips are joined in list order.';

  @override
  String get exportVideoOutputNameLabel => 'Output file name (optional)';

  @override
  String get exportVideoOutputNameHint => 'Leave empty for a timestamped name';

  @override
  String get exportVideoInvalidName =>
      'File name cannot contain \\ / : * ? \" < > |, \'..\', control characters, or reserved device names';

  @override
  String get exportVideoOverwriteWarning =>
      'A file with this name already exists — exporting will overwrite it.';

  @override
  String get exportVideoCancelExport => 'Cancel export';

  @override
  String get exportVideoMoveUp => 'Move up';

  @override
  String get exportVideoMoveDown => 'Move down';

  @override
  String get exportVideoStart => 'Export';

  @override
  String exportVideoSuccess(String path) {
    return 'Exported to $path';
  }

  @override
  String get exportVideoCopyPath => 'Copy path';

  @override
  String get exportVideoPathCopied => 'Path copied to clipboard';

  @override
  String get exportVideoFfmpegMissing =>
      'ffmpeg not found — install it and retry (set the INKFRAME_FFMPEG environment variable to use a custom location)';

  @override
  String get startupErrorTitle => 'InkFrame couldn\'t start';

  @override
  String get startupErrorBody =>
      'The embedded database failed to start or upgrade. Your projects on disk are safe. Review the logs below, then retry.';

  @override
  String get startupErrorLogPathLabel => 'Log directory';

  @override
  String get startupErrorOpenLogDir => 'Open log directory';

  @override
  String get commandPaletteTooltip => 'Command palette';

  @override
  String get commandPaletteSearchHint => 'Type a command…';

  @override
  String get commandPaletteNoResults => 'No matching commands';

  @override
  String get commandBackToStudio => 'Back to Studio';
}

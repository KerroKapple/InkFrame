// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'InkFrame';

  @override
  String get commonCancel => '取消';

  @override
  String get errorInvalidKey => 'API Key 无效，请检查 Provider 设置。';

  @override
  String get errorInsufficientBalance => 'Provider 账户余额不足。';

  @override
  String get errorContentPolicy => '内容审核拒绝了该请求。';

  @override
  String get errorInvalidParameter => '请求参数不合法。';

  @override
  String get errorNetworkTimeout => '网络超时，请稍后重试。';

  @override
  String get errorNetworkOffline => '网络不可用，请检查连接。';

  @override
  String get errorProviderServer => 'Provider 服务暂不可用，请稍后重试。';

  @override
  String get errorProviderBusy => 'Provider 繁忙，请稍后重试。';

  @override
  String get errorProviderInvalidResponse => 'Provider 返回了无效或空的结果。';

  @override
  String get errorPollTimeout => '生成任务超时未完成。';

  @override
  String get errorDownloadFailed => '下载生成产物失败。';

  @override
  String get errorLocalIO => '本地磁盘 I/O 错误，请检查空间与权限。';

  @override
  String get errorCancelled => '已被用户取消。';

  @override
  String get errorCancelledOnExit => '应用退出，已取消任务。';

  @override
  String get errorUnknown => '未知错误。';

  @override
  String get canvasNodeDefaultLabel => '新节点';

  @override
  String get canvasNodeImageType => '图片';

  @override
  String get canvasNodeTextType => '文本';

  @override
  String get canvasNodeVideoType => '视频';

  @override
  String get canvasNodeShotType => '分镜';

  @override
  String get canvasNoCanvasOpen => '当前没有打开的画布';

  @override
  String get canvasCreateSampleCanvas => '新建示例画布';

  @override
  String get canvasLoadFailed => '加载画布失败';

  @override
  String get canvasSampleProjectName => '示例项目';

  @override
  String get canvasSampleCanvasName => '画布 1';

  @override
  String get inspectorTitle => '配置';

  @override
  String get inspectorPromptLabel => '提示词';

  @override
  String get inspectorPromptHint => '描述你想生成的画面……';

  @override
  String get inspectorProviderLabel => '服务商';

  @override
  String get inspectorResolutionLabel => '分辨率';

  @override
  String get inspectorAspectRatioLabel => '宽高比';

  @override
  String get inspectorSeedLabel => '种子';

  @override
  String get inspectorSeedHint => '随机';

  @override
  String get inspectorNegativePromptLabel => '负向提示词';

  @override
  String get inspectorNegativePromptHint => '要避免的内容';

  @override
  String get inspectorBatchLabel => '数量';

  @override
  String inspectorEstimatedCost(String amount) {
    return '预估成本 $amount';
  }

  @override
  String get inspectorGenerate => '生成';

  @override
  String get inspectorGenerateDisabledEmptyPrompt => '请先填写提示词';

  @override
  String get inspectorGenerateDisabledNoKey => '请在设置中配置 API Key';

  @override
  String get inspectorStatusSubmitting => '提交中...';

  @override
  String get inspectorStatusRunning => '生成中...';

  @override
  String inspectorStatusRunningWithProgress(int percent) {
    return '生成中... $percent%';
  }

  @override
  String get inspectorStatusErrorTitle => '生成失败';

  @override
  String get inspectorRetry => '重试';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsApiKeysSection => 'API Keys';

  @override
  String get settingsApiKeysHint => 'Key 存储在系统钥匙串中，不会发送到任何外部服务。';

  @override
  String get settingsApiKeyPlaceholder => 'sk-...';

  @override
  String get settingsApiKeySave => '保存';

  @override
  String get settingsApiKeyClear => '清除';

  @override
  String get settingsApiKeySet => '已配置';

  @override
  String get settingsApiKeyNotSet => '未配置';

  @override
  String get settingsApiKeySaved => '已保存';

  @override
  String get settingsApiKeySavedUnverified => '已保存，但网络问题导致 Key 暂时无法验证。';

  @override
  String get settingsApiKeyRejected => 'Provider 拒绝了该 Key，未保存。';

  @override
  String get settingsApiKeyCleared => '已清除';

  @override
  String get settingsThemeSection => '主题';

  @override
  String get settingsCanvasSection => '画布外观';

  @override
  String get settingsCanvasEdgeColor => '连线颜色';

  @override
  String get settingsCanvasCardColor => '卡片颜色';

  @override
  String get settingsCanvasColorDefault => '主题默认';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeHighContrast => '高对比度';

  @override
  String get settingsThemeTextScale => '字号缩放';

  @override
  String get settingsLanguageSection => '语言';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageZh => '中文';

  @override
  String get settingsStorageSection => '存储';

  @override
  String get settingsStorageReadOnlyHint => '本版本数据库目录固定，后续版本会提供迁移流程。';

  @override
  String get settingsStorageDatabasePathLabel => '数据库目录';

  @override
  String get settingsStorageCopyPath => '复制路径';

  @override
  String get settingsStoragePathCopied => '路径已复制到剪贴板';

  @override
  String get settingsBackupSection => '备份与还原';

  @override
  String get settingsBackupHint => '本地数据库每日自动冷备，保留 7 份。还原只替换数据库——磁盘上的媒体文件不回滚。';

  @override
  String get settingsBackupNow => '立即备份';

  @override
  String get settingsBackupDone => '已创建备份';

  @override
  String get settingsBackupNoBinaries => '未找到内置 PostgreSQL 工具——请重新安装 InkFrame';

  @override
  String get settingsBackupFailed => '备份失败';

  @override
  String get settingsBackupsEmpty => '暂无备份';

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
  String get settingsBackupKindDaily => '每日';

  @override
  String get settingsBackupKindManual => '手动';

  @override
  String get settingsBackupKindPreRestore => '还原前';

  @override
  String get settingsRestore => '还原';

  @override
  String get restoreConfirmTitle => '从备份还原？';

  @override
  String restoreConfirmBody(String file, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat(
      'yyyy-MM-dd HH:mm',
      localeName,
    );
    final String dateString = dateDateFormat.format(date);

    return '用「$file」（$dateString）替换当前数据？还原前会尽量先备份一次；进行中的生成任务会被取消，完成后将回到主页。磁盘上的媒体文件不回滚。';
  }

  @override
  String get restoreDone => '还原完成';

  @override
  String get restoreFailed => '还原失败——你的数据未被改动';

  @override
  String get restoreFailedCorrupt => '备份文件校验未通过';

  @override
  String get restoreFailedVersionNewer => '该备份来自更新版本的 InkFrame';

  @override
  String get restoreAbortedPreBackup => '安全备份失败——已取消还原';

  @override
  String get restoreInProgress => '正在还原…';

  @override
  String get startupErrorRestoreLatest => '从最近备份还原';

  @override
  String get settingsAboutSection => '关于';

  @override
  String get settingsAboutAppNameLabel => '应用';

  @override
  String get settingsAboutVersionLabel => '版本';

  @override
  String get settingsAboutSecureStorageLabel => '安全存储';

  @override
  String get settingsAboutSecureStorageProbing => '检测中…';

  @override
  String settingsAboutSecureStorageAvailable(String backend) {
    return '可用（$backend）';
  }

  @override
  String settingsAboutSecureStorageUnavailable(String reason) {
    return '不可用：$reason';
  }

  @override
  String get settingsAboutLicensesButton => '开源许可';

  @override
  String get settingsAboutLegalese =>
      'InkFrame 以 MIT 许可发布。随附组件各自遵循其原许可：libmpv 与 FFmpeg（LGPL-2.1）、PostgreSQL（PostgreSQL License），以及 Cormorant Garamond 与 JetBrains Mono 字体（SIL OFL 1.1）。';

  @override
  String get settingsAboutUpdateCheckButton => '检查更新';

  @override
  String get settingsAboutUpdateChecking => '正在检查更新…';

  @override
  String get settingsAboutUpdateUpToDate => '已是最新版本';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return '发现新版本 $version';
  }

  @override
  String get settingsAboutUpdateViewRelease => '查看发布页';

  @override
  String get settingsAboutUpdateCheckFailed => '检查更新失败';

  @override
  String get settingsAboutUpdateOpenFailed => '无法打开发布页';

  @override
  String get settingsAboutUpdateAutoCheckLabel => '启动时自动检查更新';

  @override
  String get generationMissingKey => 'API Key 未配置';

  @override
  String generationInvalidConfig(String reason) {
    return '配置无效：$reason';
  }

  @override
  String get generationProviderNotRegistered => 'Provider 未注册';

  @override
  String get resultNodePending => '等待生成';

  @override
  String get resultNodeImageMissing => '图像文件缺失';

  @override
  String get linkModeStart => '连线';

  @override
  String get linkModeHint => '点击目标节点建立连线，点空白取消';

  @override
  String get linkCreated => '连线已创建';

  @override
  String get linkAlreadyExists => '连线已存在';

  @override
  String get linkSelfNotAllowed => '不能连到自己';

  @override
  String get linkCreateFailed => '连线创建失败';

  @override
  String get nodeDelete => '删除节点';

  @override
  String get nodeDeleted => '节点已删除';

  @override
  String nodesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已删除 $count 个节点',
    );
    return '$_temp0';
  }

  @override
  String get nodeDeleteFailed => '节点删除失败';

  @override
  String get nodeMoveFailed => '节点移动失败';

  @override
  String get edgeDeleted => '连线已删除';

  @override
  String get undoFailed => '撤销失败';

  @override
  String get inspectorInputsLabel => '输入';

  @override
  String get inspectorInputsEmpty => '无输入连线';

  @override
  String get inspectorRoleReference => '参考图';

  @override
  String get inspectorRoleFirstFrame => '首帧';

  @override
  String get inspectorRoleLastFrame => '尾帧';

  @override
  String get inspectorRemoveInput => '移除输入';

  @override
  String inspectorInputsLabelCounted(int count, int max) {
    return '输入（$count/$max）';
  }

  @override
  String inspectorInputsOverLimit(int max) {
    return '超出 Provider 上限（$max），多余参考图将被忽略';
  }

  @override
  String get inspectorPresetsSaveFailed => '预设保存失败';

  @override
  String get inspectorCharactersImportFailed => '角色导入失败';

  @override
  String get inspectorCharactersLabel => '角色';

  @override
  String get inspectorCharactersEmpty => '还没有角色';

  @override
  String get inspectorCharactersUnsupported => '当前模型不使用参考图，角色不会生效';

  @override
  String get inspectorCharactersSaveFromReference => '把参考图存为角色';

  @override
  String get inspectorCharactersImportFile => '从文件导入图片';

  @override
  String get inspectorCharactersDialogTitle => '新建角色';

  @override
  String get inspectorCharactersNameHint => '角色名称';

  @override
  String get inspectorCharactersSave => '保存';

  @override
  String get inspectorPresetsLabel => '提示词预设';

  @override
  String get inspectorPresetsEmpty => '还没有预设';

  @override
  String get inspectorPresetsSaveCurrent => '把当前提示词存为预设';

  @override
  String get inspectorPresetsDialogTitle => '新建预设';

  @override
  String get inspectorPresetsNameHint => '预设名称';

  @override
  String get batchResultsLabel => '变体';

  @override
  String get inspectorResultTitle => '结果';

  @override
  String get inspectorShotTitle => '分镜';

  @override
  String get inspectorShotNotesLabel => '分镜备注';

  @override
  String get inspectorShotNotesHint => '描述这个分镜（机位、动作、氛围）……';

  @override
  String get inspectorShotGenerateImage => '用本镜备注生成图像';

  @override
  String get inspectorShotLinkFailed => '图像节点已创建，连线失败';

  @override
  String get canvasAddImageNode => '添加图片节点';

  @override
  String get canvasAddVideoNode => '添加视频节点';

  @override
  String get canvasAddShotNode => '添加分镜节点';

  @override
  String get canvasAddNodeTooltip => '新建节点';

  @override
  String get canvasAddNodeFailed => '添加节点失败';

  @override
  String get inspectorVideoPromptLabel => '视频提示词';

  @override
  String get inspectorVideoDurationLabel => '时长（秒）';

  @override
  String inspectorVideoDurationOption(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get inspectorVideoCameraLabel => '运镜';

  @override
  String get cameraStatic => '固定机位';

  @override
  String get cameraPushIn => '推进';

  @override
  String get cameraPullOut => '拉远';

  @override
  String get cameraPanLeft => '左摇';

  @override
  String get cameraPanRight => '右摇';

  @override
  String get cameraTiltUp => '上仰';

  @override
  String get cameraTiltDown => '下俯';

  @override
  String get cameraOrbit => '环绕';

  @override
  String get cameraHandheld => '手持';

  @override
  String get inspectorVideoModeAuto => '生成模式：根据输入自动识别';

  @override
  String get inspectorVideoGenerateDisabledEmptyPrompt => '请先填写提示词';

  @override
  String get inspectorVideoGenerateDisabledNoKey => '请在设置中配置 API Key';

  @override
  String get inspectorVideoGenerate => '生成视频';

  @override
  String get lightboxClose => '关闭';

  @override
  String get lightboxPlayPause => '播放 / 暂停';

  @override
  String get studioDefaultName => '我的工作室';

  @override
  String get studioRecentProjects => '最近项目';

  @override
  String get studioNewProject => '新建项目';

  @override
  String get studioLibrary => '工作库';

  @override
  String get studioLibraryProjects => '项目';

  @override
  String get studioBreadcrumbAll => '全部项目';

  @override
  String get studioEmptyTitle => '还没有项目';

  @override
  String get studioEmptySubtitle => '新建一个项目开始你的分镜创作。';

  @override
  String get studioErrorTitle => '项目列表加载失败';

  @override
  String get studioErrorRetry => '重试';

  @override
  String get studioOpenSettings => '打开设置';

  @override
  String get studioNewProjectDialogTitle => '新建项目';

  @override
  String get studioNewProjectNameLabel => '项目名';

  @override
  String get studioNewProjectNameHint => '例如：日落劫案';

  @override
  String get studioNewProjectErrorEmpty => '请填写项目名';

  @override
  String get studioNewProjectErrorTooLong => '项目名不超过 60 个字符';

  @override
  String get studioNewProjectErrorDuplicate => '已存在同名项目';

  @override
  String get studioNewProjectFailed => '项目创建失败';

  @override
  String get studioCreate => '创建';

  @override
  String get studioRenameProject => '重命名项目';

  @override
  String get studioRename => '重命名';

  @override
  String get studioRenameFailed => '重命名项目失败';

  @override
  String get studioDeleteProject => '删除项目';

  @override
  String get studioDelete => '删除';

  @override
  String get studioDeleteConfirmTitle => '删除项目？';

  @override
  String get studioDeleteConfirmBody => '该项目及其画布将移出你的项目库。';

  @override
  String get studioDeleteFailed => '删除项目失败';

  @override
  String get studioManageCanvases => '管理画布';

  @override
  String get studioExportProject => '导出项目…';

  @override
  String get studioExportProjectDone => '项目已导出';

  @override
  String get studioExportProjectFailed => '导出项目失败';

  @override
  String get studioRenameCanvas => '重命名画布';

  @override
  String get studioRenameCanvasFailed => '重命名画布失败';

  @override
  String get studioCanvasDeleteConfirmTitle => '删除画布？';

  @override
  String get studioCanvasDeleteConfirmBody => '该画布将从项目中移除。';

  @override
  String get studioDeleteCanvasFailed => '删除画布失败';

  @override
  String get studioNoCanvases => '该项目暂无画布';

  @override
  String get commonClose => '关闭';

  @override
  String get commonUndo => '撤销';

  @override
  String get studioProjectMenuTooltip => '项目操作';

  @override
  String studioProjectMetaLine(DateTime date, int count) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMM(localeName);
    final String dateString = dateDateFormat.format(date);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个画布',
    );
    return '$dateString · $_temp0';
  }

  @override
  String get canvasDefaultName => '未命名画布';

  @override
  String get studioOpenCanvasFailed => '打开画布失败';

  @override
  String get studioNoKeyBannerText => '尚未配置任何 Provider API Key——生成需要先配置。';

  @override
  String get studioNoKeyBannerAction => '前往设置配置';

  @override
  String get studioCreateSampleProject => '创建示例项目';

  @override
  String get studioCreateSampleFailed => '创建示例项目失败';

  @override
  String get onboardingTitle => '欢迎使用 InkFrame';

  @override
  String onboardingStepIndicator(int current, int total) {
    return '第 $current 步 / 共 $total 步';
  }

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStartEmpty => '从空白开始';

  @override
  String get onboardingKeysConsoleHint =>
      '先到对应服务商控制台获取 API Key 粘贴到上方；也可以之后在设置中随时添加或修改。';

  @override
  String get onboardingStepSampleTitle => '开始创作';

  @override
  String get onboardingStepSampleBody => '创建一个示例项目快速了解画布，也可以从空白工作台开始。';

  @override
  String get canvasRenderQueue => '渲染队列';

  @override
  String get canvasRenderQueueExpand => '展开渲染队列';

  @override
  String get canvasRenderQueueCollapse => '收起渲染队列';

  @override
  String get canvasNodeTypeCharacter => '角色';

  @override
  String get canvasNodeTypeScene => '场景';

  @override
  String get canvasNodeTypeCamera => '镜头';

  @override
  String get canvasNodeTypeProp => '道具';

  @override
  String get canvasNodeTypeShot => '分镜';

  @override
  String get canvasNodeTypeImageGen => '图像生成';

  @override
  String get canvasBreadcrumbProject => '项目';

  @override
  String get canvasBreadcrumbCanvas => '画布';

  @override
  String get canvasBackToStudio => 'Studio';

  @override
  String get canvasEmptyTitle => '当前画布为空';

  @override
  String get canvasEmptySubtitle => '添加第一个节点，开始分镜。';

  @override
  String get canvasEmptyAddImage => '添加图片节点';

  @override
  String get canvasEmptyAddVideo => '添加视频节点';

  @override
  String get canvasEmptyAddShot => '添加分镜节点';

  @override
  String canvasSelectionCount(int count) {
    return '已选 $count 个';
  }

  @override
  String get canvasRenderQueueEmpty => '暂无渲染任务';

  @override
  String get canvasRenderQueueStatusQueued => '排队中';

  @override
  String get canvasRenderQueueCancel => '取消任务';

  @override
  String get canvasRenderQueueFailures => '最近失败';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowClose => '关闭';

  @override
  String get laneAdd => '添加泳道';

  @override
  String get laneNewTitle => '新建泳道';

  @override
  String get laneEditTitle => '编辑泳道';

  @override
  String get laneNameLabel => '名称';

  @override
  String get laneNameHint => '泳道名称';

  @override
  String get laneStyleLabel => '风格描述';

  @override
  String get laneStyleHint => '如：温暖的黄昏光线、烛光';

  @override
  String get laneTintLabel => '背景色';

  @override
  String get laneTintAuto => '自动';

  @override
  String get laneDelete => '删除泳道';

  @override
  String get laneDeleteConfirmTitle => '确认删除该泳道？';

  @override
  String get laneDeleteConfirmBody => '泳道内节点位置保留，但会失去该泳道风格。';

  @override
  String get laneDialogSave => '保存';

  @override
  String get laneDialogCancel => '取消';

  @override
  String get laneDirectionToggle => '切换泳道方向';

  @override
  String get laneUntitled => '未命名泳道';

  @override
  String get laneCreateFailed => '创建泳道失败';

  @override
  String get laneUpdateFailed => '更新泳道失败';

  @override
  String get laneDeleteFailed => '删除泳道失败';

  @override
  String get laneCollapse => '折叠泳道';

  @override
  String get laneExpand => '展开泳道';

  @override
  String get inspectorPromptPreviewLabel => '最终 prompt 预览';

  @override
  String get inspectorIgnoreLaneStyle => '忽略区域风格';

  @override
  String get baseStyleEditTooltip => '基底风格';

  @override
  String get baseStyleEditTitle => '项目基底风格';

  @override
  String get baseStylePrefixLabel => '前缀（加在所有 prompt 最前）';

  @override
  String get baseStylePrefixHint => '如：电影感画面';

  @override
  String get baseStyleSuffixLabel => '后缀（加在所有 prompt 最后）';

  @override
  String get baseStyleSuffixHint => '如：8k，高细节';

  @override
  String get baseStylePresetsLabel => '快速预设';

  @override
  String get baseStylePresetCinematic => '真人电影';

  @override
  String get baseStylePresetAnime => '日漫';

  @override
  String get baseStylePresetGhibli => '吉卜力';

  @override
  String get baseStylePresetCyberpunk => '赛博朋克';

  @override
  String get baseStylePresetInkwash => '水墨';

  @override
  String get baseStylePresetPhoto => '写实摄影';

  @override
  String get baseStylePreset3d => '3D动画';

  @override
  String get baseStyleUpdateFailed => '更新基底风格失败';

  @override
  String get commonRetry => '重试';

  @override
  String get galleryEntryLabel => '画廊';

  @override
  String galleryBreadcrumb(String projectName) {
    return '$projectName / 画廊';
  }

  @override
  String get galleryBackTooltip => '返回工作室';

  @override
  String get galleryEmptyTitle => '还没有生成的产物';

  @override
  String get galleryEmptySubtitle => '该项目画布上生成的图片和视频会显示在这里。';

  @override
  String get galleryLoadFailed => '画廊加载失败';

  @override
  String get galleryKindImage => '图片';

  @override
  String get galleryKindVideo => '视频';

  @override
  String get exportVideoTooltip => '导出视频';

  @override
  String get exportVideoDisabledTooltip => '画布上还没有视频生成结果';

  @override
  String get exportVideoDialogTitle => '导出视频';

  @override
  String get exportVideoDialogHint => '选中的视频将按列表顺序拼接。';

  @override
  String get exportVideoOutputNameLabel => '输出文件名（可选）';

  @override
  String get exportVideoOutputNameHint => '留空使用时间戳默认名';

  @override
  String get exportVideoInvalidName =>
      '文件名不能包含 \\ / : * ? \" < > | 字符、..、控制字符或系统保留名';

  @override
  String get exportVideoMoveUp => '上移';

  @override
  String get exportVideoMoveDown => '下移';

  @override
  String get exportVideoStart => '导出';

  @override
  String exportVideoSuccess(String path) {
    return '已导出到 $path';
  }

  @override
  String get exportVideoCopyPath => '复制路径';

  @override
  String get exportVideoPathCopied => '路径已复制到剪贴板';

  @override
  String get exportVideoFfmpegMissing =>
      '未检测到 ffmpeg——安装后重试（可用 INKFRAME_FFMPEG 环境变量指定路径）';

  @override
  String get startupErrorTitle => 'InkFrame 无法启动';

  @override
  String get startupErrorBody => '内嵌数据库启动或升级失败。磁盘上的项目数据安全无损。请查看下方日志后重试。';

  @override
  String get startupErrorLogPathLabel => '日志目录';

  @override
  String get startupErrorOpenLogDir => '打开日志目录';

  @override
  String get commandPaletteTooltip => '命令面板';

  @override
  String get commandPaletteSearchHint => '输入命令…';

  @override
  String get commandPaletteNoResults => '没有匹配的命令';

  @override
  String get commandBackToStudio => '返回 Studio';
}

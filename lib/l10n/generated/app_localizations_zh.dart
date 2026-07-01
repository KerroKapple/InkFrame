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
  String get generationMissingKey => 'API Key 未配置';

  @override
  String generationInvalidConfig(String reason) {
    return '配置无效：$reason';
  }

  @override
  String get generationProviderNotRegistered => 'Provider 未注册';

  @override
  String get generationQueueTitle => '渲染队列';

  @override
  String get generationQueueEmpty => '暂无活跃任务';

  @override
  String get generationQueueClearTerminated => '清理已完成';

  @override
  String get generationQueueRemove => '移除';

  @override
  String get generationQueueCancel => '取消任务';

  @override
  String get generationQueueRetry => '重试';

  @override
  String get generationStatusQueued => '排队中';

  @override
  String get generationStatusSubmitting => '提交中';

  @override
  String get generationStatusRunning => '生成中';

  @override
  String generationStatusRunningWithProgress(int percent) {
    return '生成中 $percent%';
  }

  @override
  String get generationStatusSucceeded => '已完成';

  @override
  String get generationStatusFailed => '失败';

  @override
  String get generationStatusCancelled => '已取消';

  @override
  String generationCountActive(int count) {
    return '$count 个进行中';
  }

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
  String get nodeDeleteFailed => '节点删除失败';

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
  String get canvasAddImageNode => '添加图片节点';

  @override
  String get canvasAddVideoNode => '添加视频节点';

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
  String get studioArchive => '归档';

  @override
  String get studioArchivedProjects => '已归档项目';

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
  String get canvasRenderQueue => '渲染队列';

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
  String canvasSelectionCount(int count) {
    return '已选 $count 个';
  }

  @override
  String get canvasRenderQueueEmpty => '暂无渲染任务';

  @override
  String get canvasRenderQueueStatusQueued => '排队中';

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
}

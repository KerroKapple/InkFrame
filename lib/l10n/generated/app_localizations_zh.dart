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
  String get commonOk => '确定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonRetry => '重试';

  @override
  String get commonClose => '关闭';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonConfirm => '确认';

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
  String get canvasEmptyHint => '右键或按 + 添加节点';

  @override
  String get canvasNodeDefaultLabel => '新节点';

  @override
  String get canvasNodeImageType => '图片';

  @override
  String get canvasAddNode => '添加节点';

  @override
  String get canvasDeleteNode => '删除节点';

  @override
  String canvasNodesSelected(int count) {
    return '已选择 $count 个节点';
  }

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
  String get workspaceTitle => '工作台';

  @override
  String get workspaceHeroTagline => 'AI 驱动的分镜创作桌面工具';

  @override
  String get workspaceHeroSubtitle => '本地运行、隐私可控；集成多个模型 Provider，一个画布把图文视频串起来';

  @override
  String get workspaceProjectsHeader => '我的项目';

  @override
  String get workspaceProjectsEmpty => '还没有项目。点右下角按钮新建第一个。';

  @override
  String get workspaceNewProject => '新建项目';

  @override
  String get workspaceNewProjectHint => '项目名';

  @override
  String get workspaceNewCanvas => '新建画布';

  @override
  String get workspaceNewCanvasHint => '画布名';

  @override
  String workspaceCanvasCount(int count) {
    return '$count 个画布';
  }

  @override
  String get workspaceOpenCanvas => '打开';

  @override
  String get workspaceBackToWorkspace => '返回工作台';

  @override
  String get workspaceLoadError => '项目列表加载失败';

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
  String get inspectorGenerate => '生成';

  @override
  String get inspectorGenerateDisabledEmptyPrompt => '请先填写提示词';

  @override
  String get inspectorGenerateDisabledNoKey => '请在设置中配置 API Key';

  @override
  String get inspectorGenerateNotWiredYet => '生成流程将在下个切片接入';

  @override
  String get inspectorSelectSingleHint => '选中一个配置节点以编辑';

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
  String get generationSuccess => '生成完成';

  @override
  String get generationFailure => '生成失败';

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
  String get canvasAddVideoNode => '新增视频节点';

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
  String get inspectorVideoModeAuto => '生成模式：根据输入自动识别';

  @override
  String get inspectorVideoModeT2v => '文生视频';

  @override
  String get inspectorVideoModeI2v => '图生视频';

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
  String get lockTagline => '为分镜师而生的工作台';

  @override
  String get lockKeyPlaceholder => '粘贴 Provider Key...';

  @override
  String get lockKeyHelpLine1 => '从你的 Provider 后台获取 API Key。';

  @override
  String get lockKeyHelpLine2 => '我们不会把 Key 存到服务器。';

  @override
  String get lockUnlock => '解锁';

  @override
  String get lockKeyInvalid => 'Key 无效或网络错误，请重试。';

  @override
  String get studioRecentProjects => '最近项目';

  @override
  String get studioNewProject => '新建项目';

  @override
  String get studioLibrary => '工作库';

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
  String get canvasInspectorTransform => '变换';

  @override
  String get canvasInspectorCamera => '镜头';

  @override
  String get canvasInspectorComposition => '构图';

  @override
  String get canvasInspectorMetadata => '元数据';

  @override
  String get canvasInspectorNotes => '备注';

  @override
  String get canvasInspectorAddAttribute => '添加属性';

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
  String get canvasInspectorKindCamera => '镜头节点';

  @override
  String get canvasInspectorMockTitle => '宽景镜头';

  @override
  String get canvasInspectorMockId => 'cam_0021';

  @override
  String get canvasRenderQueueJobWatch => '怀表特写';

  @override
  String get canvasRenderQueueJobHarbor => '港口码头';

  @override
  String get canvasRenderQueueJobNocturne => '夜曲预告';

  @override
  String get canvasRenderQueueStatusQueued => '排队中';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowClose => '关闭';
}

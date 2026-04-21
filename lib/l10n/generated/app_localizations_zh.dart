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
}

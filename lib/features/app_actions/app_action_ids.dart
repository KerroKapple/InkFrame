// 应用级动作的 id：菜单栏、右键菜单、⌘K、快捷键页按 id 取同一行动作（app_action_catalog.dart）。
//
// 有的 id 本片只定名、还没登记成行（帮助组全部、文件组的导出项目 / 交付 / 回收站 / 退出、窗口组的切标签、
// 节点组的「加入泳道 ›」）：由后续切片（help-actions / win-menubar）往动作表里追加，id 用这里的。
abstract final class AppActionIds {
  // ===== 文件 =====
  static const String newProject = 'newProject';

  /// 打开短剧示例（帮助菜单复用同一个 id）。
  static const String openSampleProject = 'openSampleProject';
  static const String importProject = 'importProject';
  static const String exportVideo = 'exportVideo';
  static const String openSettings = 'openSettings';
  static const String exportProject = 'exportProject';
  static const String deliver = 'deliver';
  static const String trash = 'trash';
  static const String quit = 'quit';

  // ===== 编辑 =====
  static const String undo = 'undo';
  static const String redo = 'redo';
  static const String cut = 'cut';
  static const String copy = 'copy';
  static const String paste = 'paste';
  static const String duplicate = 'duplicate';
  static const String delete = 'delete';
  static const String selectAll = 'selectAll';
  static const String find = 'find';
  static const String commandPalette = 'commandPalette';

  // ===== 画布 =====
  static const String openCreateMenu = 'openCreateMenu';
  static const String addImageNode = 'addImageNode';
  static const String addVideoNode = 'addVideoNode';
  static const String addTextNode = 'addTextNode';
  static const String addShotNode = 'addShotNode';
  static const String newNote = 'newNote';
  static const String addLane = 'addLane';
  static const String toggleLink = 'toggleLink';
  static const String importScript = 'importScript';
  static const String importMedia = 'importMedia';
  static const String selectTool = 'selectTool';
  static const String panTool = 'panTool';
  static const String zoomIn = 'zoomIn';
  static const String zoomOut = 'zoomOut';
  static const String zoomReset = 'zoomReset';
  static const String fitAll = 'fitAll';
  static const String fitSelection = 'fitSelection';
  static const String toggleLeftRail = 'toggleLeftRail';

  // ===== 节点 =====
  static const String generate = 'generate';
  static const String saveAsCharacter = 'saveAsCharacter';
  static const String wrapInLane = 'wrapInLane';
  static const String removeFromLane = 'removeFromLane';
  static const String locateInSequence = 'locateInSequence';

  /// 「加入泳道 ›」带子菜单，归菜单栏切片。
  static const String addToLane = 'addToLane';

  // ===== 窗口 =====
  static const String backToStudio = 'backToStudio';
  static const String focusNotifications = 'focusNotifications';
  static const String showStudio = 'showStudio';
  static const String showCanvas = 'showCanvas';
  static const String showSequence = 'showSequence';
  static const String showGallery = 'showGallery';
  static const String showExport = 'showExport';
  static const String showTasks = 'showTasks';

  // ===== 帮助 =====
  static const String helpShortcuts = 'helpShortcuts';
  static const String helpOnboarding = 'helpOnboarding';
  static const String helpReleaseNotes = 'helpReleaseNotes';
  static const String helpFeedback = 'helpFeedback';
  static const String helpManual = 'helpManual';
  static const String helpExportDiagnostics = 'helpExportDiagnostics';
  static const String helpOpenLogDir = 'helpOpenLogDir';
  static const String helpCheckUpdate = 'helpCheckUpdate';
  static const String helpAbout = 'helpAbout';
}

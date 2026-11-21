// ai-pose-gallery-zh 图库的协议字面量：数据文件名、JSON 字段名（中文）、成人向分类。
//
// 字段名是图库数据的协议，不是界面文案，不进 ARB。条目名、分类名是内容数据，原样显示。
abstract final class AiPoseGalleryZhKeys {
  /// 数据文件所在的子目录（相对图库根目录）。图片路径则相对图库根目录本身。
  static const String dataDir = 'data';

  // —— 只读这四个文件。动漫服装、CharaDB 只有原站链接、没有本地图，深度图不接。
  static const String poseFile = 'pose-zh.json';
  static const String portraitFile = 'portrait-zh.json';
  static const String costumeFile = 'costume-zh.json';
  static const String costumeShiseiFile = 'costume-shisei-zh.json';

  // —— 四个文件共有的字段。
  static const String id = 'id';
  static const String thumb = '缩略图';
  static const String original = '原图';

  /// 服装文件里的预览图；历代服装没有 [original] 时退到它。
  static const String preview = '预览图';
  static const String search = '检索';

  // —— 姿势。
  static const String poseSystem = '体系';
  static const String poseGroup = '分类';
  static const String poseName = '姿势名称';
  static const String poseAngle = '角度';

  // —— 人像。
  static const String portraitGroup = '分区';
  static const String portraitName = '标题';

  // —— 服装（costume-zh 与 costume-shisei-zh 同一套字段）。
  static const String costumeGroup = '分类';
  static const String costumeName = '服装名称';

  /// 成人向，默认隐藏（这一版不做开关）：姿势按 [poseSystem] 判。
  static const Set<String> adultPoseSystems = <String>{
    '全身单人・性感系',
    '双人缠绵',
  };

  /// 成人向，默认隐藏：服装按 [costumeGroup] 判。
  static const Set<String> adultCostumeGroups = <String>{
    '内衣・睡衣',
    '性感穿搭',
  };
}

// SB-1 规则脚本拆分器。
//
// 用户从别处（剧本、大纲、聊天记录）粘一段文本过来，要变成一串分镜草稿。
// 纯规则、零 LLM——没有 API key 也能用，这是 D-M4-1 拍 A 档的理由。
//
// 最容易写漏的是**剥行首编号**：用户粘过来的文本十有八九带 `1.` / `镜头1` /
// `SHOT 1` / `#` 这类前缀，留着它们会污染 prompt（"1. 山径破晓" 会让模型
// 去画一个数字 1）。但也不能剥过头——"1920 年代的街道"里的数字是内容。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/storyboard/util/script_splitter.dart';

List<String> _notes(List<ShotDraft> d) => d.map((e) => e.notes).toList();
List<String> _labels(List<ShotDraft> d) => d.map((e) => e.label).toList();

void main() {
  group('splitScript · blankLine 策略', () {
    test('空行分段', () {
      final out = splitScript('第一段\n还是第一段\n\n第二段');
      expect(_notes(out), ['第一段\n还是第一段', '第二段']);
    });

    test('连续多个空行只算一个分隔', () {
      final out = splitScript('A\n\n\n\nB');
      expect(_notes(out), ['A', 'B']);
    });

    test('只含空白的行也算空行（用户从 Word 粘过来常见）', () {
      final out = splitScript('A\n   \t \nB');
      expect(_notes(out), ['A', 'B']);
    });

    test('首尾空行不产生空草稿', () {
      final out = splitScript('\n\n  \nA\n\n\n');
      expect(_notes(out), ['A']);
    });

    test('CRLF 与 CR 统一成 LF', () {
      expect(_notes(splitScript('A\r\n\r\nB')), ['A', 'B']);
      expect(_notes(splitScript('A\r\rB')), ['A', 'B']);
    });

    test('段内每行各自 trim 行尾空白,但保留换行结构', () {
      final out = splitScript('第一行   \n第二行\t\n\n下一段');
      expect(out.first.notes, '第一行\n第二行');
    });
  });

  group('splitScript · perLine 策略', () {
    test('每行一镜,空行被跳过', () {
      final out = splitScript(
        'A\n\nB\nC',
        strategy: ScriptSplitStrategy.perLine,
      );
      expect(_notes(out), ['A', 'B', 'C']);
    });

    test('perLine 下段落里的换行不再粘在一起', () {
      final out = splitScript(
        '山径破晓\n渡索桥',
        strategy: ScriptSplitStrategy.perLine,
      );
      expect(out, hasLength(2));
    });
  });

  group('剥行首编号', () {
    test('阿拉伯数字 + 常见分隔符', () {
      for (final prefix in <String>[
        '1. ',
        '1) ',
        '1、',
        '1．',
        '01. ',
        '12.',
      ]) {
        expect(
          splitScript('$prefix山径破晓').single.notes,
          '山径破晓',
          reason: '未剥掉前缀「$prefix」',
        );
      }
    });

    test('中文「镜头N」/「第N镜」', () {
      expect(splitScript('镜头1 山径破晓').single.notes, '山径破晓');
      expect(splitScript('镜头 2：渡索桥').single.notes, '渡索桥');
      expect(splitScript('第3镜 茶棚避雨').single.notes, '茶棚避雨');
      expect(splitScript('第 4 镜、竹林夜行').single.notes, '竹林夜行');
    });

    test('英文 SHOT N / Scene N（大小写不敏感）', () {
      expect(splitScript('SHOT 1 dawn ridge').single.notes, 'dawn ridge');
      expect(splitScript('shot 2: rope bridge').single.notes, 'rope bridge');
      expect(splitScript('Scene 3 - tea shed').single.notes, 'tea shed');
    });

    test('markdown 标题井号', () {
      expect(splitScript('# 山径破晓').single.notes, '山径破晓');
      expect(splitScript('### Shot 1 dawn').single.notes, 'dawn');
    });

    test('只剥**段首那一行**的编号,段内后续行不动', () {
      final out = splitScript('1. 山径破晓\n2 号机位跟拍');
      expect(out.single.notes, '山径破晓\n2 号机位跟拍');
    });

    test('不误伤：数字是内容的一部分时不剥', () {
      // 后面没有分隔符也没有空格 → 不是编号。
      expect(splitScript('1920 年代的街道').single.notes, '1920 年代的街道');
      expect(splitScript('3D 渲染质感').single.notes, '3D 渲染质感');
    });

    test('剥完只剩空 → 整段丢弃,不产生空草稿', () {
      expect(splitScript('1.\n\n真正的内容'), hasLength(1));
      expect(splitScript('1.\n\n真正的内容').single.notes, '真正的内容');
    });
  });

  group('label', () {
    test('取段首行', () {
      final out = splitScript('山径破晓\n晨光初现,旅人只是山脊线上的剪影');
      expect(out.single.label, '山径破晓');
    });

    test('超长首行截到 60 字,不留半个省略号以外的残缺', () {
      final long = 'x' * 200;
      final out = splitScript(long);
      expect(out.single.label.length, lessThanOrEqualTo(60));
      // notes 保留全文——截断只影响展示用的 label。
      expect(out.single.notes.length, 200);
    });

    test('label 也剥编号（否则节点标题会是「1. 山径破晓」）', () {
      expect(splitScript('1. 山径破晓\n正文').single.label, '山径破晓');
    });
  });

  group('退化输入', () {
    test('空文本 / 纯空白 → 空清单', () {
      expect(splitScript(''), isEmpty);
      expect(splitScript('   \n\t\n  '), isEmpty);
      expect(splitScript('\r\n\r\n'), isEmpty);
    });

    test('单行无分隔 → 一镜', () {
      expect(splitScript('就一句话'), hasLength(1));
    });

    test('结果顺序即输入顺序', () {
      final out = splitScript('A\n\nB\n\nC');
      expect(_labels(out), ['A', 'B', 'C']);
    });
  });

  group('ShotDraft', () {
    test('值相等', () {
      const a = ShotDraft(label: 'x', notes: 'y');
      const b = ShotDraft(label: 'x', notes: 'y');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}

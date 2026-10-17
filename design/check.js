// 结构自检：标签闭合 + {{ }} 洞只能是点路径 + 脚本能被解析
const fs = require('fs');
const f = process.argv[2];
const s = fs.readFileSync(f, 'utf8');
const holes = [...s.matchAll(/\{\{\s*([^}]*?)\s*\}\}/g)].map((m) => m[1]);
const bad = holes.filter((h) => !/^[A-Za-z_$][\w$]*(\.[A-Za-z_$][\w$]*)*$/.test(h) && h !== 'true' && h !== 'false');
const voids = new Set(['img', 'br', 'hr', 'meta', 'link', 'input', 'source']);
const body = s.slice(s.indexOf('<x-dc>'), s.indexOf('</x-dc>') + 7);
const re = /<\/?([a-zA-Z][\w-]*)([^>]*?)(\/?)>/g; const st = []; let m; let errs = 0;
while ((m = re.exec(body))) {
  const tag = m[1].toLowerCase();
  if (m[0].startsWith('</')) { const top = st.pop(); if (top !== tag) { console.log('mismatch', top, tag, body.slice(Math.max(0, m.index - 60), m.index + 20)); if (++errs > 3) break; } }
  else if (!voids.has(tag) && m[3] !== '/') st.push(tag);
}
const script = s.slice(s.indexOf('data-dc-script'), s.lastIndexOf('</script>'));
const code = script.slice(script.indexOf('>') + 1);
let parse = 'ok';
try { new Function('DCLogic', code + '\n;return Component;'); } catch (e) { parse = e.message; }
const props = s.match(/data-props='([^']*)'/);
let propsOk = 'ok'; try { JSON.parse(props[1]); } catch (e) { propsOk = e.message; }
console.log(f, 'bytes', s.length, 'holes', holes.length, 'bad', bad, 'unclosed', st.slice(-4), 'errs', errs, 'script', parse, 'props', propsOk);

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dependency } from './deps.mjs';
export const root = fileURLToPath(new URL('../', import.meta.url));
export async function build() {
  const upstream = await readFile(root+'upstream/worker.snapshot.mjs');
  if(createHash('sha256').update(upstream).digest('hex')!=='f58e27e36f41219d68f7ed3469fcb75c0d88d2fbf6b209ce4deb592920906122') throw Error('Upstream snapshot changed');
  const panel = await readFile(root+'upstream/admin.snapshot.html','utf8');
  if(createHash('sha256').update(panel).digest('hex')!=='0ab22a9f361e6a2ba0547778488574440af278d47e10ecf9e2cc6e8d66d516c7') throw Error('Panel snapshot changed');
  await mkdir(root+'dist',{recursive:true});
  // Named exports expose existing verifiers without rewriting their implementation.
  await writeFile(root+'dist/upstream.mjs',upstream+'\nexport {verifyAppAuth, verifyAuth, createJWT};\n');
  // Staging must never inherit the production URL embedded in the old panel.
  const sameOrigin = panel.replace("const API_URL = 'https://vini-v2-api.loboangel39.workers.dev';", 'const API_URL = location.origin;');
  if(sameOrigin===panel)throw Error('Expected panel API constant not found');
  const enhanced = sameOrigin.replace('</body>', '<script>'+await readFile(root+'panel/admin-extension.js','utf8')+'</script></body>');
  await writeFile(root+'dist/admin.html',enhanced);
  await writeFile(root+'dist/panel.mjs','export default '+JSON.stringify(enhanced)+';');
  await dependency('esbuild').build({entryPoints:[root+'src/worker.mjs'],outfile:root+'dist/worker.mjs',bundle:true,format:'esm',platform:'browser',target:'es2022',loader:{'.sql':'text'},logLevel:'warning'});
  return root+'dist/worker.mjs';
}
if(process.argv[1]===fileURLToPath(import.meta.url)) await build();

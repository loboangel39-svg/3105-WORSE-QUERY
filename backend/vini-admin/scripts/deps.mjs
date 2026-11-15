import { createRequire } from 'node:module';
export const dependency = createRequire(process.env.VINI_WRANGLER_PACKAGE || new URL('../package.json', import.meta.url));

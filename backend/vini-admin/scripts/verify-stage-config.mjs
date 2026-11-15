import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
export async function verifyStage(){
  const config=JSON.parse(await readFile(new URL('../wrangler.remote-staging.jsonc',import.meta.url),'utf8'));
  if(config.name!=='vini-admin-plans-staging-2b'||config.routes?.length||config.r2_buckets?.length||config.d1_databases?.length!==1)throw Error('Unsafe staging config');
  const db=config.d1_databases[0];
  if(db.binding!=='DB'||db.database_name!=='vini-admin-plans-staging-2b-db'||db.database_id!=='cd4adf09-e968-455b-8825-5832bc5ed2c5')throw Error('Unexpected staging D1 identity');
  return config;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){await verifyStage();console.log('PASS: dedicated staging Worker/D1; no production bindings or routes')}

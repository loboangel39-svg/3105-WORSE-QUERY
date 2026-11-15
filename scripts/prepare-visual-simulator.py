"""Boot a fresh iPhone simulator in the disposable CI VM; never touches a real device."""
import json,subprocess,sys
from pathlib import Path
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
def run(args,timeout=180):
 return subprocess.run(args,capture_output=True,text=True,check=True,timeout=timeout).stdout
# The image may have a service started under its default Xcode before xcode-select.
subprocess.run(['killall','-9','com.apple.CoreSimulator.CoreSimulatorService'],capture_output=True,timeout=15)
runtimes=json.loads(run(['xcrun','simctl','list','runtimes','-j']))
(out/'runtimes.json').write_text(json.dumps(runtimes,indent=2))
eligible=[r for r in runtimes['runtimes'] if r.get('isAvailable') and r['name'].startswith('iOS ') and int(r['version'].split('.')[0])>=26]
runtime=max(eligible,key=lambda r:tuple(map(int,r['version'].split('.'))))
types=json.loads(run(['xcrun','simctl','list','devicetypes','-j']))['devicetypes']
deviceType=next(t for t in types if t['name']=='iPhone 13 Pro Max')
device=run(['xcrun','simctl','create','3105 visual validation',deviceType['identifier'],runtime['identifier']]).strip()
(out/'selected-device.json').write_text(json.dumps({'udid':device,'model':deviceType['name'],'runtime':runtime['name']},indent=2))
run(['xcrun','simctl','boot',device],120)
with (out/'boot.log').open('w') as log:
 subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=420)
print(device)

"""Preserve 0959a41 engine/identity and dashboard graphics; no app launch."""
from pathlib import Path
import subprocess,re
root=Path(__file__).resolve().parents[1]
def original(path):return subprocess.check_output(['git','show','0959a41:'+path],cwd=root).decode().replace('\r\n','\n')
def text(path):return (root/path).read_text(encoding='utf-8')
protected=['ThreeOneOSFive/Info.plist','ThreeOneOSFive/3105-Experimental.entitlements','ThreeOneOSFive/helpers/PatchPackageCodec.swift','ThreeOneOSFive/helpers/PatchProjectModels.swift','ThreeOneOSFive/helpers/PatchProjectLibrary.swift','ThreeOneOSFive/helpers/SupportPolicy.swift','ThreeOneOSFive/helpers/VINICompatibility.swift','ThreeOneOSFive/helpers/VINIDualBackupStore.swift']
protected+=subprocess.check_output(['git','ls-files','Vendor','ThreeOneOSFive/exploit'],cwd=root).decode().splitlines()
for path in protected:
 a=(root/path).read_bytes().replace(b'\r\n',b'\n')
 b=subprocess.check_output(['git','show','0959a41:'+path],cwd=root).replace(b'\r\n',b'\n')
 assert a==b,path
path='ThreeOneOSFive/views/VINIDashboardView.swift';old,new=original(path),text(path)
for name in ['VINICategorySelector','VINITargetCard','VINISystemInfoCard']:
 def component(s):return s.split('struct '+name+': View {',1)[1].split('\nstruct ',1)[0]
 assert component(old)==component(new),name+' changed'
for pattern in [r'.*\.padding\(.*',r'.*\.background\(.*',r'.*\.overlay\(.*']:
 assert re.findall(pattern,old)==re.findall(pattern,new),'dashboard geometry/color changed'
assert re.findall(r'target\(".*',old)==re.findall(r'target\(".*',new)
client=text('ThreeOneOSFive/helpers/VINIStagingClient.swift')
assert 'vini-v2-api.' not in client and 'vini-admin-plans-staging-2b.loboangel39.workers.dev' in client
assert 'X-New-Token' not in client and 'UserDefaults' not in client and not re.search(r'\b(print|log)\(',client)
assert 'completionHandler(nil)' in client and 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' in client
for word in ['DevicePatchService','PatchTransaction','WQIntegrated','Apply','Restore']:
 assert word not in text('ThreeOneOSFive/views/VINIStagingAccountView.swift').replace('// Keep previous rows visible on connection loss. They never authorize download/Apply.',''),word
for path in (root/'.github/workflows').glob('*.yml'):
 for forbidden in ['simctl','iphonesimulator','coresimulator','runfirstlaunch']:assert forbidden not in path.read_text().lower(),str(path)
print('PASS preserved dashboard graphics/categories, engines, identity, codec, compatibility and physical-only workflows; staging only and Keychain credentials')

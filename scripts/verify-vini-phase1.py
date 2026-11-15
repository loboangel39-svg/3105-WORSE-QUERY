"""Static checks only: no device, virtual device, network or executable launch."""
from pathlib import Path
import hashlib, json, re, runpy, subprocess, sys
sys.dont_write_bytecode = True
root=Path(__file__).resolve().parents[1]
def read(p): return (root/p).read_text(encoding='utf-8')
source=read('ThreeOneOSFive/views/VINIDashboardView.swift')
entry=read('ThreeOneOSFive/App.swift').split('class AppState:',1)[0]
assert 'VINIDashboardView()' in entry and 'ContentView()' not in entry
for name in ['VINIDashboardView','VINIHeaderView','VINILicenseCard','VINICategorySelector','VINITargetCard','VINISystemInfoCard']:
 assert 'struct '+name+': View' in source,name
for forbidden in ['TextField(', 'AppSearchField(', 'ControllerNavigation(', 'TabView(', '.searchable(', 'ProgressView(', 'LogView(', 'AppUpdateChecker', 'URLSession', 'Timer(', 'FileManager', 'PatchTransaction', 'DevicePatchService', 'WQIntegrated', '.onAppear', '.task']:
 assert forbidden not in source, 'unexpected dashboard capability: '+forbidden
assert set(re.findall(r'^import (\w+)',source,re.M))=={'SwiftUI','Foundation'}
assert 'packageID: nil' in source and 'targetID: "preview." + id' in source
assert 'availability: .preview, patchState: .unknown' in source
assert 'isVerified: false, verifiedRemainingSeconds: nil' in source
assert '@State private var previewSelection: Set<String>' in source
assert 'previewSelection.insert(target.targetID)' in source and 'previewSelection.remove(target.targetID)' in source
assert 'Toggle(target.title, isOn: $isOn)' in source
assert 'guard license.isVerified' in source
assert source.count('@AppStorage(')==1 and '@AppStorage("interface.appearance")' in source
assert 'if typeSize.isAccessibilitySize' in source
assert 'accessibilityReduceMotion' in source and 'minHeight: 44' in source
items=re.findall(r'target\("([^"\n]+)", \.(\w+), "([^"\n]+)"',source)
assert len(items)==10 and len({i[0] for i in items})==10
assert [i[2] for i in items if i[1]=='combat']==['Aim Drag Pro','Aimbot Cabeza','Aimbot Cuello','Aimbot Pecho','Balas Mágicas / Direct Hit']
assert {i[1] for i in items}=={'combat','visuals','offsets'}
for path in (root/'.github/workflows').glob('*.yml'):
 text=path.read_text().lower()
 for forbidden in ['simctl','iphonesimulator','coresimulator','runfirstlaunch','prepare-visual-simulator','run-wqfiles-integration-smoke','prepare-ui-tests','run_all_tests.sh']:
  assert forbidden not in text, f'forbidden active validation: {path.name}: {forbidden}'
project=read('ThreeOneOSFive.xcodeproj/project.pbxproj')
assert 'VINIDashboardView.swift in Sources' in project
base_project=subprocess.check_output(['git','show','18d3694:ThreeOneOSFive.xcodeproj/project.pbxproj'],cwd=root).decode().replace('\r\n','\n')
project_without_vini='\n'.join(l for l in project.split('\n') if 'AA310501000000000000000' not in l)
assert project_without_vini==base_project, 'build settings, identity or original target membership changed'
for name in ['PlusJakartaSans','JetBrainsMono']:
 font=root/f'ThreeOneOSFive/WQFilesResources.bundle/Fonts/{name}.ttf'
 assert font.read_bytes()[:4] in [b'\x00\x01\x00\x00',b'OTTO']
 assert 'SIL OPEN FONT LICENSE' in read(f'ThreeOneOSFive/WQFilesResources.bundle/Fonts/{name}-OFL.txt')
for script in ['verify-visual-redesign.py','verify-ui-cleanup.py','verify-wqfiles-integration.py']:
 runpy.run_path(str(root/'scripts'/script),run_name='__main__')
print('PASS: VINI Phase 1 preview-only dashboard; 6 reusable components, 3 categories, 10 preview targets, no legacy navigation/search, no switch operations, verified-license placeholder, font licenses, unchanged device identity and physical-only workflows')

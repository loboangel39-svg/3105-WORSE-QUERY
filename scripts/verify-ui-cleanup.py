"""Focused localization/startup/network and unchanged-engine regression checks."""
from pathlib import Path
import json, re, subprocess, plistlib
root = Path(__file__).resolve().parents[1]
def read(name): return (root/name).read_text(encoding='utf-8')
def table(name):
    entries = re.findall(r'^\s*("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*");',read(name),re.M)
    parsed = [(json.loads(k),json.loads(v)) for k,v in entries]
    assert len(parsed)==len(dict(parsed)), name+' duplicate keys'
    return dict(parsed)
base='ThreeOneOSFive/'
en=table(base+'en.lproj/Localizable.strings'); es=table(base+'es.lproj/Localizable.strings')
assert en.keys()==es.keys()
fmt=re.compile(r"%(?:\d+\$)?[-+ #0']*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|[hljztLq])?[@diuoxXfFeEgGaAcCsSpn%]")
for k,v in es.items():
    assert v.strip(), k
    assert fmt.findall(en[k])==fmt.findall(v), (k,en[k],v)
assert es['tab.installed']=='Instalados' and es['tab.files']=='Archivos' and es['tab.search']=='Buscar'
assert read('Vendor/WQFiles/es.lproj/Localizable.strings')==read(base+'WQFilesResources.bundle/es.lproj/Localizable.strings')
app=read(base+'App.swift'); startup=app.split('class AppState:')[0]
for forbidden in ('OnboardingView(', 'AppUpdateChecker', 'displayIdentityAttribution', 'updateOffer'): assert forbidden not in startup
assert startup.count('WQIntegratedInitialize()')==1
assert 'onOpenURL' in startup and 'patchDraftCoordinator.presentImport(url)' in startup
assert 'AppLanguage.spanish.rawValue' in startup and 'defaultValue = AppLanguage.spanish' in read(base+'helpers/Localization.swift')
nav=read(base+'helpers/AppTabNavigationState.swift')
assert 'case .installed, .files, .search: return true' in nav
assert 'selectedTab: Int = AppSection.installed.rawValue' in nav
assert 'static func check() async -> Offer? { nil }' in read(base+'helpers/Utils.swift')
native=read('Vendor/WQFiles/main.m')
assert native.count('if (!WQSilentRefresh()) [self checkForUpdate];')==2
assert len(re.findall(r'- \(void\)checkForUpdate\s*\{\s*if \(WQSilentRefresh\(\)\) return;',native))==2
assert len(re.findall(r'- \(void\)showUpdateBanner[^\n]*\n\{\s*if \(WQSilentRefresh\(\)\) return;',native))==2
assert 'creditsRow(' not in read(base+'views/SettingsView.swift')
assert 'OPEN_SOURCE_LICENSES' in native and 'OPEN_SOURCE_LICENSES' in read(base+'views/SettingsView.swift')
for path in [base+'Info.plist',base+'WQFilesResources.bundle/Info.plist']:
    assert plistlib.loads((root/path).read_bytes())['CFBundleDevelopmentRegion']=='es'
# Compare all behavior outside the deliberately replaced startup and update check.
def old(path): return subprocess.check_output(['git','show','a5df58f:'+path],cwd=root).decode('utf-8').replace('\r\n','\n')
assert app.split('class AppState:',1)[1]==old(base+'App.swift').split('class AppState:',1)[1]
# The protected-file suite hashes access, identity, patch, editor, backup, cleaner and refresh implementation.
import runpy
runpy.run_path(str(root/'scripts/verify-silent-refresh.py'),run_name='__main__')
print(f'PASS: {len(es)} Spanish keys, format arguments, bundled UIKit Spanish, startup/import wiring, no app-version requests and preserved AppState')

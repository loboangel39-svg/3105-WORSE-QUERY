from pathlib import Path
import subprocess, hashlib, json, re
root=Path(__file__).resolve().parents[1]
def old(p): return subprocess.check_output(['git','show','18d3694:'+p],cwd=root).decode('utf-8').replace('\r\n','\n')
def read(p): return (root/p).read_text(encoding='utf-8')
def trim(s): return '\n'.join(l for l in s.split('\n') if l.strip() not in ('.controllerSurface()', '.controllerRow()', '.accessibilityIdentifier("files-workspace")', '.accessibilityIdentifier("folder-browser")'))
# Every pre-existing executable source outside this explicit presentation allowlist is identical to the stable commit.
allowed={'ThreeOneOSFive/ContentView.swift','ThreeOneOSFive/views/DesignSystem.swift','ThreeOneOSFive/views/SettingsView.swift'}
from native_presentation import normalized
for path in ['Vendor/WQFiles/main.m','Vendor/WQFiles/WQUI.m']:
 assert normalized(read(path))==normalized(old(path)), 'non-presentation UIKit change: '+path
 allowed.add(path)
style_only=['AppDataBrowserView.swift','FileBrowserView.swift','PatchProjectsView.swift','RepositoryHomeView.swift','RepositoryMarketplaceView.swift']
for name in style_only:
 p='ThreeOneOSFive/views/'+name
 assert trim(read(p)).replace('.buttonStyle(ControllerButtonStyle())', '.buttonStyle(.bordered)')==old(p), 'non-presentation change: '+p
 allowed.add(p)
paths=subprocess.check_output(['git','ls-tree','-r','--name-only','18d3694','ThreeOneOSFive','Vendor/WQFiles'],cwd=root,text=True).splitlines()
count=0
for p in paths:
 if p.endswith(('.swift','.m','.mm','.c','.h','.inc','.entitlements')) and p not in allowed:
  assert read(p)==old(p), 'protected executable/identity source changed: '+p
  count+=1
for lang in ['es','en','vi','zh-Hans']:
 p=f'ThreeOneOSFive/{lang}.lproj/Localizable.strings'
 def table(s): return {json.loads(k):json.loads(v) for k,v in re.findall(r'^("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*");',s,re.M)}
 before,after=table(old(p)),table(read(p))
 assert all(after[k]==v for k,v in before.items()), lang
 assert set(after)-set(before)=={'appearance.title','appearance.dark','appearance.light','appearance.system'}
assert 'case .installed, .files, .search: return true' in read('ThreeOneOSFive/helpers/AppTabNavigationState.swift')
assert 'ControllerNavigation(' in read('ThreeOneOSFive/ContentView.swift')
assert 'interface.appearance' in read('ThreeOneOSFive/views/SettingsView.swift')
print(f'PASS: {count} executable/identity files identical to 18d3694; five view files differ only by explicit styling modifiers; existing localized text unchanged')

settings=trim(read('ThreeOneOSFive/views/SettingsView.swift'))
settings=settings.replace('    @AppStorage("interface.appearance") private var appearance = "dark"\n','')
start=settings.index('                Section(language.text("appearance.title")) {')
end=settings.index('                Section(language.text("settings.language")) {',start)
settings=settings[:start]+settings[end:]
assert settings==old('ThreeOneOSFive/views/SettingsView.swift'), 'settings behavior changed outside new presentation preferences'
content=read('ThreeOneOSFive/ContentView.swift')
for line in ['    @AppStorage("interface.appearance") private var appearance = "dark"','        AppTheme.configure()','        .font(AppTheme.sans())','        .preferredColorScheme(appearance == "system" ? nil : appearance == "light" ? .light : .dark)','        .background(ControllerCanvas())','                    .toolbar(.hidden, for: .tabBar)']:
 content=content.replace(line+'\n','')
def without_compact(text):
 a=text.index('    private var compactLayout:')
 b=text.index('    private var regularLayout:',a)
 return text[:a]+text[b:]
content=without_compact(content)
assert content==without_compact(old('ThreeOneOSFive/ContentView.swift')), 'navigation behavior changed outside presentation'
print('PASS: settings callbacks and all navigation/import/session wiring identical after removing explicit presentation additions')

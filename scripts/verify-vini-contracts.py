"""Static preservation checks. Does not launch an iOS app or virtual device."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
def read(path): return (root / path).read_text(encoding='utf-8')
def base(path):
    return subprocess.check_output(['git', 'show', 'a89d075:'+path], cwd=root).decode().replace('\r\n', '\n')

path = 'ThreeOneOSFive/views/VINIDashboardView.swift'
old, new = base(path), read(path)
def component(text, name):
    tail = text.split('struct '+name+': View {', 1)[1]
    return tail.split('\nstruct ', 1)[0]
for name in ['VINIHeaderView', 'VINILicenseCard', 'VINICategorySelector']:
    assert component(new, name) == component(old, name), name+' layout changed'
card = component(new, 'VINITargetCard')
card = card.replace('Text(target.patchDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false\n'
    '                     ? target.patchDescription! : language.text("vini.no_patch"))\n'
    '                    .font', 'Text(language.text(target.descriptionKey)).font')
card = card.replace('.disabled(target.availability != .available)', '.disabled(target.availability == .unavailable)')
assert card == component(old, 'VINITargetCard'), 'card graphics changed'
panel = component(new, 'VINISystemInfoCard')
panel = re.sub(r'    private var compatibility: VINICompatibility \{.*?\n    \}\n', '', panel, flags=re.S)
panel = panel.replace('language.text(compatibility.documented ? "vini.compatible" : "vini.not_verified")', 'language.text("vini.preview_mode")')
assert panel == component(old, 'VINISystemInfoCard'), 'system panel graphics changed'
assert 'previewSelection.insert' not in new and 'previewSelection.remove' not in new
assert 'availability: .unavailable, patchState: .unknown' in new
assert 'initialPreviewSelection: []' in new
assert 'userName: "—", plan: "—"' in new
assert 'isVerified: false, verifiedRemainingSeconds: nil' in new
assert 'targetID: "vini." + id' in new
assert re.findall(r'target\(".*', old) == re.findall(r'target\(".*', new), 'names/icons changed'
for lang in ['es','en','vi','zh-Hans']:
    text = read('ThreeOneOSFive/'+lang+'.lproj/Localizable.strings')
    assert '"vini.target.' not in text
    for key in ['no_patch', 'compatible', 'not_verified']:
        assert '"vini.'+key+'" =' in text
# The supplement must not change existing access policy, engines or identity.
for path in ['ThreeOneOSFive/helpers/SupportPolicy.swift', 'ThreeOneOSFive/App.swift',
             'ThreeOneOSFive/Info.plist', 'ThreeOneOSFive/3105-Experimental.entitlements',
             'ThreeOneOSFive/helpers/PatchProjectLibrary.swift',
             'ThreeOneOSFive/helpers/PatchPackageCodec.swift']:
    assert read(path) == base(path), path+' changed'
for relative in subprocess.check_output(['git','ls-files','Vendor/WQFiles'],cwd=root).decode().splitlines():
    path = root/relative
    original = subprocess.check_output(['git','show','a89d075:'+relative],cwd=root)
    # Binary files and LF/CRLF source checkouts are both supported.
    assert path.read_bytes().replace(b'\r\n',b'\n') == original.replace(b'\r\n',b'\n'), relative
project = read('ThreeOneOSFive.xcodeproj/project.pbxproj')
without_new = '\n'.join(line for line in project.split('\n') if 'AA31050200000000000000' not in line and 'AA31050300000000000000' not in line)
assert without_new == base('ThreeOneOSFive.xcodeproj/project.pbxproj'), 'build settings/identity changed'
for file in ['VINICompatibility.swift','VINIRemoteContract.swift','VINIPackageCatalog.swift','VINIDualBackupStore.swift']:
    assert file+' in Sources' in project
for workflow in (root/'.github/workflows').glob('*.yml'):
    text = workflow.read_text().lower()
    for forbidden in ['simctl','iphonesimulator','coresimulator','runfirstlaunch']:
        assert forbidden not in text, str(workflow)
contract = read('ThreeOneOSFive/helpers/VINIRemoteContract.swift')
assert 'URLSession' not in contract.replace('// No URLSession,', '// No transport,')
print('PASS: unchanged card graphics, header, categories, panel geometry, names/icons, access engines, package codec/library, identity and physical-only workflows; inert remote contracts')

# Adds test-only targets to the disposable CI checkout; production identity is unchanged.
require 'xcodeproj'
p = Xcodeproj::Project.open('ThreeOneOSFive.xcodeproj')
app = p.targets.find { |t| t.name == '3105' }
t = p.new_target(:ui_test_bundle, 'UICleanupTests', :ios, '26.0')
t.add_dependency(app)
files = ['Tests/UICleanupTests.swift', 'ThreeOneOSFive/helpers/AppTabNavigationState.swift', 'ThreeOneOSFive/helpers/PatchProjectModels.swift', 'ThreeOneOSFive/helpers/PatchPackageCodec.swift']
files.each { |file| t.source_build_phase.add_file_reference(p.main_group.new_file(file)) }
t.build_configurations.each do |c|
 c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'org.3105.UICleanupTests'
 c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
 c.build_settings['SWIFT_VERSION'] = '5.0'
 c.build_settings['TEST_TARGET_NAME'] = '3105'
 c.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end
p.save
s = Xcodeproj::XCScheme.new
s.add_build_target(app)
s.add_test_target(t)
s.set_launch_target(app)
s.test_action.build_configuration = 'Debug'
s.save_as(p.path, 'UICleanupTests', true)

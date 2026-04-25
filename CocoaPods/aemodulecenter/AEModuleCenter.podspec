Pod::Spec.new do |s|
  s.name             = 'AEModuleCenter'
  s.version          = '1.0.0'
  s.summary          = 'A thread-safe module management center for iOS applications.'
  s.description      = <<-DESC
                       AEModuleCenter provides a centralized, thread-safe way to manage modules
                       in your iOS application. It handles module registration, removal, and
                       lifecycle event forwarding to all registered modules.

                       Features:
                       - Thread-safe module registration and removal
                       - Automatic lifecycle event forwarding
                       - Weak reference to modules to avoid memory leaks
                       - Support for all major UIApplication lifecycle events
                       DESC

  s.homepage         = 'https://github.com/junqit/aemodulecenter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'junqit' => 'junqit@github.com' }
  s.source           = { :git => 'git@github.com:junqit/aemodulecenter.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
  s.swift_version = '5.0'

  s.source_files = 'AEModuleCenter/Classes/**/*.swift'

  s.frameworks = 'Foundation'
  s.ios.frameworks = 'UIKit'
  s.osx.frameworks = 'AppKit'

  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0'
  }
end

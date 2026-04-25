Pod::Spec.new do |s|
  s.name             = 'AEAINetworkModule'
  s.version          = '1.0.0'
  s.summary          = 'AEAI Network initialization module for managing UDP socket connections.'
  s.description      = <<-DESC
                       AEAINetworkModule provides network initialization functionality for AEAI applications.
                       It implements AEModuleProtocol to initialize UDP socket connections during application
                       startup, making it available for AEAIEngin to use.

                       Features:
                       - Automatic UDP socket initialization on app launch
                       - Integration with AEModuleCenter for lifecycle management
                       - Configurable network settings
                       - Thread-safe network manager access
                       DESC

  s.homepage         = 'https://github.com/junqit/aeainetworkmodule'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'junqit' => 'junqit@github.com' }
  s.source           = { :git => 'git@github.com:junqit/aeainetworkmodule.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'

  s.source_files = 'AEAINetworkModule/Classes/**/*.swift'

  s.frameworks = 'Foundation'

  s.dependency 'AEModuleCenter'
  s.dependency 'AENetworkEngine'

  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0'
  }
end

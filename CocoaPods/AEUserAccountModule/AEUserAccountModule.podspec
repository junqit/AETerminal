Pod::Spec.new do |spec|

  spec.name         = "AEUserAccountModule"
  spec.version      = "0.0.1"
  spec.summary      = "User account module providing uid and ident information"

  spec.description  = <<-DESC
                      AEUserAccountModule - User account management module for iOS and macOS.
                      Provides user uid, ident and related account information via protocol.
                   DESC

  spec.homepage     = "https://github.com/yourusername/AEUserAccountModule"
  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "tianjunqi" => "tianjunqi@xiaomi.com" }

  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.15"

  spec.source       = { :git => "git.", :tag => "#{spec.version}" }

  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }

  spec.source_files = 'AEUserAccountModule/Classes/**/*.swift'

  spec.dependency 'AELogProxy'
  spec.dependency 'AEModuleCenter'
  spec.dependency 'AEFoundation'

end

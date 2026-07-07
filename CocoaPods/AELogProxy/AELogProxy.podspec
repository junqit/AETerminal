Pod::Spec.new do |spec|

  spec.name         = "AELogProxy"
  spec.version      = "0.0.1"
  spec.summary      = "AELogProxy - Unified logging proxy for AE modules"

  spec.description  = <<-DESC
                      AELogProxy - Provides a simple unified logging function for all AE modules.
                      Automatically includes file name and line number in debug builds.
                   DESC

  spec.homepage     = "https://github.com/yourusername/AELogProxy"
  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "tianjunqi" => "tianjunqi@xiaomi.com" }

  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.15"

  spec.source       = { :git => "git.", :tag => "#{spec.version}" }

  spec.source_files = 'AELogProxy/Classes/**/*.swift'

  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }

end

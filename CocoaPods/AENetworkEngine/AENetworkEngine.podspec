#
#  Be sure to run `pod spec lint MIWBTCore.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  
  spec.name         = "AENetworkEngine"
  spec.version      = "0.0.1"
  spec.summary      = "A short description of AENetworkEngine"

  spec.description  = <<-DESC
                      AENetworkEngine
                   DESC

  spec.homepage     = "https://git.n.xiaomi.com/miwearbluetooth/miwbtcore"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  
  spec.author             = { "tianjunqi" => "tianjunqi@xiaomi.com" }
  
  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.15"

  spec.source       = { :git => "git.", :tag => "#{spec.version}" }
 
  spec.default_subspecs = 'HTTP', 'Socket'

  spec.subspec 'Core' do |ss|
    ss.source_files = 'Core/**/*.swift'
  end

  spec.subspec 'HTTP' do |ss|
    ss.source_files = 'HTTP/**/*.swift'
    ss.dependency 'AENetworkEngine/Core'
  end

  spec.subspec 'Socket' do |ss|
    ss.source_files = 'Socket/**/*.swift'
    ss.dependency 'AENetworkEngine/Core'
  end

end


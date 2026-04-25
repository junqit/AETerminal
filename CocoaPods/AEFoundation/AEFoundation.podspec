#
#  Be sure to run `pod spec lint AEFoundation.podspec' to ensure this is a
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

  spec.name         = "AEFoundation"
  spec.version      = "0.0.1"
  spec.summary      = "AEFoundation - Foundation utilities and extensions"

  spec.description  = <<-DESC
                      AEFoundation - Foundation utilities and extensions for iOS and macOS
                   DESC

  spec.homepage     = "https://github.com/yourusername/AEFoundation"
  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author             = { "tianjunqi" => "tianjunqi@xiaomi.com" }

  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.15"

  spec.source       = { :git => "git.", :tag => "#{spec.version}" }

  spec.source_files = '**/*.swift'

  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }

end

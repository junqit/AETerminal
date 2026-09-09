Pod::Spec.new do |s|
  s.name             = 'AECloudStorage'
  s.version          = '1.0.0'
  s.summary          = 'AECloudStorage - 云存储抽象（provider + file CRUD）+ 百度网盘实现。'
  s.description      = <<-DESC
                       AECloudStorage 提供云存储抽象层（AECloudStorage 协议 + AECloudFile 值对象/CRUD）
                       与百度网盘 provider（AEBaiduStorage）：OAuth、list/upload/download/mkdir。
                       DESC

  s.homepage         = 'https://github.com/junqit/aecloudstorage'
  s.license          = { :type => 'MIT' }
  s.author           = { 'junqit' => 'junqit@github' }
  s.source           = { :git => 'git@github.com:junqit/aecloudstorage.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'

  s.source_files = 'AECloudStorage/Classes/**/*.swift', 'Storages/**/*.swift'
  s.frameworks = 'Foundation'

  s.dependency 'AELogProxy'
  s.dependency 'AEModuleCenter'

  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0'
  }
end

Pod::Spec.new do |s|
  s.name             = 'AEWebModule'
  s.version          = '1.0.0'
  s.summary          = 'AEWebModule - 用 WKWebView 加载网页的浏览器能力模块。'
  s.description      = <<-DESC
                       AEWebModule 提供基于 WKWebView 的应用内网页加载能力：
                       - 加载并展示网页 URL
                       - 返回 / 前进 / 刷新导航
                       - 加载进度 + 页面标题
                       - native <-> JS 桥（AEWebScriptHandler）
                       DESC

  s.homepage         = 'https://github.com/junqit/aewebmodule'
  s.license          = { :type => 'MIT' }
  s.author           = { 'junqit' => 'junqit@github' }
  s.source           = { :git => 'git@github.com:junqit/aewebmodule.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'

  s.source_files = 'AEWebModule/Classes/**/*.swift'
  s.frameworks = 'Foundation', 'WebKit'

  s.dependency 'AELogProxy'
  s.dependency 'AEModuleCenter'

  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0'
  }
end

Pod::Spec.new do |s|
  s.name             = 'AEAIModule'
  s.version          = '0.1.0'
  s.summary          = 'AI Terminal UI Module'
  s.description      = <<-DESC
                       AI Terminal UI Module包含聊天视图、左侧目录视图、右侧输入视图、
                       键盘处理、组合键管理和自定义文本输入框，用于构建AI终端界面。
                       DESC

  s.homepage         = 'https://github.com/yourusername/AEAIModule'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tianjunqi' => 'your.email@example.com' }
  s.source           = { :git => 'https://github.com/yourusername/AEAIModule.git', :tag => s.version.to_s }

  s.platform         = :osx
  s.osx.deployment_target = '10.15'
  s.swift_version    = '5.0'

  s.source_files     = 'AEAIModule/**/*'

  # 依赖的其他 Pods
  s.dependency 'AEFoundation'
  s.dependency 'AEAIEngin'
  s.dependency 'AENetworkEngine'

  # Frameworks
  s.frameworks       = 'Foundation', 'AppKit'
end



#
# Be sure to run `pod lib lint APICodable.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CommonLog'
  s.version          = '2.0'
  s.summary          = 'Print log to console'
  s.description      = <<-DESC
Manage & pring logs.
                       DESC
  s.homepage         = 'git@github.com:GZR-iOS/CommonLog'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'DươngPQ' => 'duongpq@runsystem.net' }
  s.source           = { :git => 'git@github.com:GZR-iOS/CommonLog.git', :branch => "version/" + s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.12'
  s.source_files     = 'CMLogging.swift'
end

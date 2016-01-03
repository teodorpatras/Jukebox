#
# Be sure to run `pod lib lint Jukebox.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Jukebox"
  s.version          = "0.1.0"
  s.summary          = "Jukebox is an iOS audio player written in Swift."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.homepage         = "https://github.com/teodorpatras/Jukebox"
  s.license          = 'MIT'
  s.author           = { "Teodor Patras" => "me@teodorpatras.com" }
  s.source           = { :git => "https://github.com/teodorpatras/Jukebox.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/teodorpatras'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'Jukebox' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'Foundation', 'AVFoundation', 'MediaPlayer'
  # s.dependency 'AFNetworking', '~> 2.3'
end

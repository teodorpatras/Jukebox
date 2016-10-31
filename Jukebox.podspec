Pod::Spec.new do |s|
  s.name             = "Jukebox"
  s.version          = "0.2.1"
  s.summary          = "Jukebox is an iOS audio player written in Swift."

  s.homepage         = "https://github.com/teodorpatras/Jukebox"
  s.license          = 'MIT'
  s.author           = { "Teodor Patras" => "me@teodorpatras.com" }
  s.source           = { :git => "https://github.com/teodorpatras/Jukebox.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/teodorpatras'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Source/*.swift'

  s.frameworks = 'Foundation', 'AVFoundation', 'MediaPlayer'
end

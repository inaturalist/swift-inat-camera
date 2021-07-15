Pod::Spec.new do |s|

  s.name           = "swift-inat-camera"
  s.version        = "1.0.0"
  s.summary        = "Swift iNat Camera"
  s.homepage       = "https://github.com/inaturalist/swift-inat-camera"
  s.license        = "MIT"
  s.author         = "iNaturalist"
  s.platform       = :ios, "9.0"
  s.source         = { :git => "https://github.com/inaturalist/swift-inat-camera.git", :tag => "main" }
  s.source_files   = "ios/**/*.{h,m}"
  s.preserve_paths = 'README.md', 'LICENSE', 'package.json', 'index.js'

  s.dependency     "React"

end

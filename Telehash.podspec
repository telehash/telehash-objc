Pod::Spec.new do |s|
  s.name         = "Telehash"
  s.version      = "0.0.2"
  s.summary      = "Telehash Switch in Objective-C for iOS and Desktop"
  s.description  = <<-DESC
                   Objective-C library for Telehash - a distributed secure wire protocol.
                   DESC
  s.homepage     = "http://telehash.org"
  s.license      = 'BSD'
  s.author             = { "Jeremie Miller" => "https://github.com/quartzjer/", "Andy Muldowney" => "https://github.com/andymuldowney/", "Thomas Muldowney" => "https://github.com/temas/" }
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'

  s.source       = { :git => "https://github.com/telehash/objc.git", :commit => "4f96b0e224a52240073487a69a5df04215a11166" }
  s.source_files  = 'common/*.{h,m}', 'crypto', 'cryptopp/cryptopp/*.{h,cpp}'
	s.exclude_files = 'crypto/CryptoPPUtil.mm', 'cryptopp/cryptopp/wake.*', 'cryptopp/cryptopp/bench.*', 'cryptopp/cryptopp/bench2.*', 'cryptopp/cryptopp/test.*', 'cryptopp/cryptopp/validat1.*', 'cryptopp/cryptopp/validat2.*', 'cryptopp/cryptopp/validat3.*', 'cryptopp/cryptopp/adhoc.*', 'cryptopp/cryptopp/adhoc.*', 'cryptopp/cryptopp/datatest.*', 'cryptopp/cryptopp/regtest.*', 'cryptopp/cryptopp/fipsalgt.*', 'cryptopp/cryptopp/dlltest.*'

	s.libraries = 'c++'
	s.xcconfig = { 'OTHER_LDFLAGS' => '-ObjC -all_load', 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/Telehash/cryptopp/**', 'OTHER_CPLUSPLUSFLAGS' => '-stdlib=libc++' }

end

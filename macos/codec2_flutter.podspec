Pod::Spec.new do |s|
  s.name             = 'codec2_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter FFI plugin wrapping Codec2 ultra-low-bitrate speech codec.'
  s.homepage         = 'https://github.com/dz0ny/meshcore-sar'
  s.license          = { :type => 'LGPL-2.1', :file => '../src/codec2/COPYING' }
  s.author           = { 'MeshCore SAR' => 'noreply@example.com' }
  s.source           = { :path => '.' }

  s.platform              = :osx, '10.14'
  s.swift_version         = '5.0'

  # All Codec2 C sources are unity-built via Classes/codec2_amalgam.c,
  # which #includes them relative to that file.  CocoaPods only picks up
  # files inside the pod directory tree, so we cannot reference ../src directly.
  s.source_files = 'Classes/**/*'

  s.public_header_files = []
  s.pod_target_xcconfig = {
    # The amalgam includes codec2 headers; point the compiler at them.
    'HEADER_SEARCH_PATHS' => "$(PODS_TARGET_SRCROOT)/../src/codec2/src $(PODS_TARGET_SRCROOT)/../src/codec2_generated",
    'GCC_PREPROCESSOR_DEFINITIONS' => 'DUMP=0 CORTEX_M4=0',
    'DEFINES_MODULE' => 'YES',
  }

  s.dependency 'FlutterMacOS'
end

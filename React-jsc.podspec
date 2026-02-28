# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
version = package['version']

folly_config = get_folly_config()
folly_compiler_flags = folly_config[:compiler_flags]
boost_config = get_boost_config()
boost_compiler_flags = boost_config[:compiler_flags]

Pod::Spec.new do |s|
  s.name                   = "React-jsc"
  s.version                = version
  s.summary                = "JavaScriptCore engine for React Native"
  s.homepage               = "https://github.com/react-native-community/javascriptcore"
  s.license                = package["license"]
  s.author                 = "Meta Platforms, Inc. and its affiliates"
  s.platforms              = { :ios => "15.1", :tvos => "15.1", :visionos => "1.0", :osx => "10.15" }
  s.source                 = { :git => "https://github.com/react-native-community/javascriptcore.git", :tag => "#{s.version}" }
  s.source_files           = "common/*.{cpp,h}", "apple/*.{mm,h}"
  s.compiler_flags = folly_compiler_flags + ' ' + boost_compiler_flags
  s.weak_framework         = "JavaScriptCore"
  s.pod_target_xcconfig    = {
    "CLANG_CXX_LANGUAGE_STANDARD" => rct_cxx_language_standard(),
    "DEFINES_MODULE" => "YES",
  }
  s.module_name            = "ReactJSC"

  # Direct dependencies
  s.dependency "React-cxxreact"
  s.dependency "React-jsi"

  # Dependencies with non-standard framework names need add_dependency
  # for correct HEADER_SEARCH_PATHS under use_frameworks!
  add_dependency(s, "React-jsinspector", :framework_name => 'jsinspector_modern')
  add_dependency(s, "React-jsinspectorcdp", :framework_name => 'jsinspector_moderncdp')
  add_dependency(s, "React-jsinspectortracing", :framework_name => 'jsinspector_moderntracing')
  add_dependency(s, "React-runtimeexecutor", :additional_framework_paths => ["platform/ios"])
  add_dependency(s, "React-oscompat")
  add_dependency(s, "React-jsitooling", :framework_name => "JSITooling")

  # Transitive deps whose headers are reached through the above pods' headers.
  # Unlike React-hermes (which lives inside ReactCommon/ and uses
  # $(PODS_TARGET_SRCROOT)/.. to resolve sibling headers), this pod lives in
  # node_modules/ so it needs explicit HEADER_SEARCH_PATHS for these.
  add_dependency(s, "React-timing", :framework_name => 'React_timing')
  add_dependency(s, "React-debug", :framework_name => 'React_debug')
  add_dependency(s, "React-utils", :framework_name => 'React_utils')

  add_rn_third_party_dependencies(s)
end

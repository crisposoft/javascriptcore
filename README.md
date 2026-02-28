# React Native JavaScriptCore (Fork)

> **Fork of [`@react-native-community/javascriptcore`](https://github.com/react-native-community/javascriptcore)** with fixes for React Native **0.84+**, `use_frameworks! :linkage => :static`, and New Architecture.

This fork rewrites the iOS podspec to work with RN 0.84's module system and fixes header resolution issues that occur when using `use_frameworks!`.

_JavaScriptCore was extracted from core react-native as part of the [Lean Core JSC RFC](https://github.com/react-native-community/discussions-and-proposals/blob/main/proposals/0836-lean-core-jsc.md) ([PR](https://github.com/react-native-community/discussions-and-proposals/pull/836))._

## Known Issues & Upstream PRs

The following issues exist in React Native core and require patches (see [Required Patches](#3-required-react-native-patches-via-patch-package) below):

| Issue | Description | PR |
|-------|-------------|-----|
| [#54268](https://github.com/facebook/react-native/issues/54268) | Hermes pods still installed when `USE_THIRD_PARTY_JSC=1` | [#55817](https://github.com/facebook/react-native/pull/55817) |
| Compile error | `createJSRuntimeFactory` missing `#else` branch | [#55817](https://github.com/facebook/react-native/pull/55817) |

## iOS Setup Guide (React Native 0.84+)

### 1. Install the package

```sh
npm install github:crisposoft/javascriptcore
# or
yarn add github:crisposoft/javascriptcore
```

Also install [`patch-package`](https://github.com/ds300/patch-package) if you don't have it already:

```sh
npm install --save-dev patch-package
```

### 2. Environment variables in Podfile

Add these environment variables **at the top** of your `ios/Podfile`, before any `target` blocks:

```ruby
# Use JSC instead of Hermes
ENV['USE_THIRD_PARTY_JSC'] = '1'
ENV['USE_HERMES'] = '0'

# Force building RN dependencies from source (required for JSC compatibility)
ENV['RCT_USE_RN_DEP'] = '0'
```

> **Why `RCT_USE_RN_DEP=0`?** RN 0.84 defaults to prebuilt `ReactNativeDependencies` xcframework which bundles Folly, DoubleConversion, glog, and boost. Building from source avoids conflicts with the JSC pod.

### 3. Required React Native patches (via patch-package)

React Native 0.84 has several bugs that prevent JSC from working. Create `patches/react-native+0.84.1.patch` (adjust version to match yours) with the following content:

<details>
<summary>Click to expand full patch</summary>

```diff
diff --git a/node_modules/react-native/Libraries/AppDelegate/RCTDefaultReactNativeFactoryDelegate.mm b/node_modules/react-native/Libraries/AppDelegate/RCTDefaultReactNativeFactoryDelegate.mm
index 3b917c1..3960753 100644
--- a/node_modules/react-native/Libraries/AppDelegate/RCTDefaultReactNativeFactoryDelegate.mm
+++ b/node_modules/react-native/Libraries/AppDelegate/RCTDefaultReactNativeFactoryDelegate.mm
@@ -45,6 +45,10 @@ - (JSRuntimeFactoryRef)createJSRuntimeFactory
 {
 #if USE_THIRD_PARTY_JSC != 1
   return jsrt_create_hermes_factory();
+#else
+  [NSException raise:@"JSRuntimeFactory"
+              format:@"createJSRuntimeFactory must be overridden when using third-party JSC"];
+  return nil;
 #endif
 }
 
diff --git a/node_modules/react-native/scripts/react_native_pods.rb b/node_modules/react-native/scripts/react_native_pods.rb
index 231f420..0679f34 100644
--- a/node_modules/react-native/scripts/react_native_pods.rb
+++ b/node_modules/react-native/scripts/react_native_pods.rb
@@ -75,7 +75,7 @@ def use_react_native! (
   error_if_try_to_use_jsc_from_core()
   warn_if_new_arch_disabled()
 
-  hermes_enabled= true
+  hermes_enabled= !use_third_party_jsc()
   # Set the app_path as env variable so the podspecs can access it.
   ENV['APP_PATH'] = app_path
   ENV['REACT_NATIVE_PATH'] = path
```

</details>

#### What each patch fixes:

1. **`RCTDefaultReactNativeFactoryDelegate.mm` — `createJSRuntimeFactory`**: Adds an `#else` branch so the method has a return value when `USE_THIRD_PARTY_JSC=1`. Without this, the build fails with a "non-void function does not return a value" error.

2. **`react_native_pods.rb` — `hermes_enabled`**: The `hermes_enabled` flag is hardcoded to `true`, ignoring `USE_THIRD_PARTY_JSC`. This causes `hermes-engine`, `React-hermes`, and `React-RuntimeHermes` pods to always be installed. The patch sets `hermes_enabled = !use_third_party_jsc()` so Hermes pods are excluded when JSC is configured.

After creating the patch file, make sure your `package.json` has a postinstall script:

```json
{
  "scripts": {
    "postinstall": "patch-package"
  }
}
```

### 4. Podfile post_install — compiler flags

Add these compiler flags in your `post_install` block so that C++ preprocessor guards throughout React Native correctly detect the JSC configuration:

```ruby
post_install do |installer|
  react_native_post_install(installer, "../node_modules/react-native")

  # Inject JSC/Hermes preprocessor flags at the Xcode project level
  if use_third_party_jsc()
    ReactNativePodsUtils.add_compiler_flag_to_project(installer, "-DUSE_THIRD_PARTY_JSC=1")
    ReactNativePodsUtils.add_compiler_flag_to_project(installer, "-DUSE_HERMES=0")
  end
end
```

> **Why is this needed?** `RCTCxxBridge.mm` and other RN source files check `#if !defined(USE_HERMES)` or `#if USE_THIRD_PARTY_JSC`. The podspec-level `js_engine_flags()` is dead code in RN 0.84, so these flags must be injected at the project level.

### 5. AppDelegate — override `createJSRuntimeFactory`

#### Objective-C (`AppDelegate.mm`)

```objc
#import <ReactJSC/RCTJscInstanceFactory.h>

// Inside your AppDelegate implementation:

- (JSRuntimeFactoryRef)createJSRuntimeFactory
{
  return jsrt_create_jsc_factory();
}
```

#### Swift (`AppDelegate.swift`)

```swift
import ReactJSC

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func createJSRuntimeFactory() -> JSRuntimeFactoryRef {
    jsrt_create_jsc_factory()
  }
}
```

### 6. Run pod install

```sh
cd ios && pod install
```

You should see that `hermes-engine`, `React-hermes`, and `React-RuntimeHermes` are **not** in the installed pods. The total pod count should be ~3 fewer than with Hermes.

## Full Podfile Example

```ruby
ENV['USE_THIRD_PARTY_JSC'] = '1'
ENV['USE_HERMES'] = '0'
ENV['RCT_USE_RN_DEP'] = '0'

def node_require(script)
  require Pod::Executable.execute_command('node', ['-p',
    "require.resolve('#{script}', {paths: [process.argv[1]]})", __dir__]).strip
end

node_require('react-native/scripts/react_native_pods.rb')

platform :ios, min_ios_version_supported
prepare_react_native_project!

use_frameworks! :linkage => :static

target 'MyApp' do
  config = use_native_modules!

  use_react_native!(
    :path => config[:reactNativePath],
    :app_path => "#{Pod::Config.instance.installation_root}/.."
  )
end

post_install do |installer|
  react_native_post_install(installer, "../node_modules/react-native")

  if use_third_party_jsc()
    ReactNativePodsUtils.add_compiler_flag_to_project(installer, "-DUSE_THIRD_PARTY_JSC=1")
    ReactNativePodsUtils.add_compiler_flag_to_project(installer, "-DUSE_HERMES=0")
  end
end
```

## Android

### `android/gradle.properties`

```properties
hermesEnabled=false
useThirdPartyJSC=true
```

### `MainApplication.kt`

```diff
+import io.github.reactnativecommunity.javascriptcore.JSCExecutorFactory
+import io.github.reactnativecommunity.javascriptcore.JSCRuntimeFactory
+import com.facebook.react.bridge.JavaScriptExecutorFactory
+import com.facebook.react.modules.systeminfo.AndroidInfoHelpers

 class MainApplication : Application(), ReactApplication {

   override val reactNativeHost: ReactNativeHost =
       object : DefaultReactNativeHost(this) {
         // ...
+        override fun getJavaScriptExecutorFactory(): JavaScriptExecutorFactory =
+          JSCExecutorFactory(packageName, AndroidInfoHelpers.getFriendlyDeviceName())
       }

+  override val reactHost: ReactHost
+    get() = getDefaultReactHost(applicationContext, reactNativeHost, JSCRuntimeFactory())
 }
```

## Fork Changes vs Upstream

This fork ([crisposoft/javascriptcore](https://github.com/crisposoft/javascriptcore)) includes the following changes over the [upstream](https://github.com/react-native-community/javascriptcore):

- **Podspec rewrite**: Uses `add_dependency` helper with correct framework names for all transitive dependencies, fixing header resolution with `use_frameworks!`
- **Non-modular header fix**: Forward-declares `JSRuntimeFactoryRef` in the public header instead of importing the non-modular `<react/runtime/JSRuntimeFactoryCAPI.h>`, avoiding "include of non-modular header inside framework module" errors
- **`package.json` fix**: Corrected `files` field from `["ios", ...]` to `["apple", ...]` to match the actual directory structure

## Maintainers

### Upstream

- [Callstack](https://callstack.com/)
- [Expo](https://expo.dev/)

### Fork

- [Crisposoft](https://github.com/crisposoft)

### Special Thanks

Special thanks to the team who worked on the initial extraction of JavaScriptCore from core react-native:

- [Riccardo Cipolleschi](https://github.com/cipolleschi)
- [Nicola Corti](https://github.com/cortinico)
- [Kudo Chien](https://github.com/Kudo)
- [Oskar Kwaśniewski](https://github.com/okwasniewski)
- [jsc-android](https://github.com/react-native-community/jsc-android-buildscripts)

## License

Everything inside this repository is [MIT licensed](./LICENSE).

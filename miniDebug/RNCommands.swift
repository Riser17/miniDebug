import Foundation
                                                                                                                                                                                                                                                                               
  struct RNCommands {
      let projectPath: String
      let adbPath: String
                                                                                                                                                                                                                                                                               
      var runIOS: String { "npx react-native run-ios --no-packager" }
      var runAndroid: String { "npx react-native run-android --no-packager" }

      // Filtered to React Native's own JS console tag (ReactNativeJS, all levels)
      // and Java-side fatal crashes (AndroidRuntime errors only). Everything else
      // (kernel boot messages, unrelated system processes, other apps) is silenced
      // via "*:S" - otherwise generic error-detection regexes false-positive on
      // unrelated system log noise.
      var logAndroid: String { "\(adbPath) logcat -c && \(adbPath) logcat ReactNativeJS:V AndroidRuntime:E \"*:S\"" }
      // Catches all React Native JS logs (console.*, redbox errors) via the
      // actual subsystem, plus native fatal crashes.
      var logIOS: String {
          "xcrun simctl spawn booted log stream --style compact --level debug --predicate 'subsystem == \"com.facebook.react.log\" OR eventMessage CONTAINS[cd] \"FATAL EXCEPTION\" OR eventMessage CONTAINS[cd] \"Fatal Exception\"'"
      }

      var reloadIOS: String {
           "osascript -e 'tell application \"Simulator\" to activate' -e 'tell application \"System Events\" to keystroke \"r\" using command down'"
       }
      var reloadAndroid: String { "\(adbPath) shell input keyevent 29" }
                                                                                                                                                                                                                                                                               
      var inspectIOS: String {
          "osascript -e 'tell application \"Simulator\" to activate' -e 'tell application \"System Events\" to keystroke \"d\" using command down'"
      }
      var inspectAndroid: String { "\(adbPath) shell input keyevent 82" }
      var devtools: String { "open -a 'Google Chrome' 'chrome://inspect' && open 'http://localhost:8081'" }
      var deepCleanIOS: String { "rm -rf node_modules && npm install && cd ios && xcodebuild clean all" }
      var deepCleanAndroid: String { "rm -rf node_modules && npm install && cd android && ./gradlew clean" }
      var podUpdate: String { "cd ios && pod install" }
      var metroReset: String { "npx react-native start --reset-cache" }
      // NEW: Simple start command
           var startMetro: String { "npm start" }
  }

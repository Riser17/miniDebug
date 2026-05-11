import Foundation
                                                                                                                                                                                                                                                                               
  struct RNCommands {
      let projectPath: String
      let adbPath: String
                                                                                                                                                                                                                                                                               
      var runIOS: String { "npx react-native run-ios --no-packager" }
      var runAndroid: String { "npx react-native run-android --no-packager" }
                                                                                                                                                                                                                                                                               
      var logAndroid: String { "\(adbPath) logcat" }
                                                                                                                                                                                                                                                                               
      var reloadIOS: String {
           "osascript -e 'tell application \"Simulator\" to activate' -e 'tell application \"System Events\" to keystroke \"r\" using command down'"
       }
      var reloadAndroid: String { "\(adbPath) shell input keyevent 29" }
                                                                                                                                                                                                                                                                               
      var inspectIOS: String {
          "osascript -e 'tell application \"Simulator\" to activate' -e 'tell application \"System Events\" to keystroke \"d\" using command down'"
      }
      var inspectAndroid: String { "\(adbPath) shell input keyevent 82" }
      var devtools: String { "open http://localhost:8081/debugger-ui" }
      var deepCleanIOS: String { "rm -rf node_modules && npm install && cd ios && xcodebuild clean all" }
      var deepCleanAndroid: String { "rm -rf node_modules && npm install && cd android && ./gradlew clean" }
      var podUpdate: String { "cd ios && pod install" }
      var metroReset: String { "npx react-native start --reset-cache" }
      // NEW: Simple start command
           var startMetro: String { "npm start" }
  }

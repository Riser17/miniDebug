import Foundation
                                                                                                                                                                                                             
struct RNCommands {
    let projectPath: String
    // Absolute path for your specific user
    let adbPath: String = "/Users/harshvardhanrathore/Library/Android/sdk/platform-tools/adb"
                                                                                                                                                                                                             
    // --no-packager prevents the CLI from trying to open a new terminal window
    var runIOS: String { "npx react-native run-ios --no-packager" }
    var runAndroid: String { "npx react-native run-android --no-packager" }
                                                                                                                                                                                                             
    var logAndroid: String { "\(adbPath) logcat" }
                                                                                                                                                                                                             
    // Target 'System Events' instead of 'Simulator' to send key presses
    var reloadIOS: String {
         "osascript -e 'tell application \"Simulator\" to activate' -e 'tell application \"System Events\" to keystroke \"r\" using command down'"
     }    
    var reloadAndroid: String { "\(adbPath) shell input keyevent 29" }
}

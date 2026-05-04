  
  # 🚀 miniDebug                                                                                                                                                                                               
                                                                                                                                                                                                               
  `miniDebug` is a lightweight macOS utility designed for React Native developers to control iOS and Android simulators directly from a GUI, eliminating the need to switch back and forth between the terminal
   and the simulator for common tasks.                                                                                                                                                                         
                                                                                                                                                                                                               
  ## ✨ Features                                                                                                                                                                                               
   
  - **One-Click Run**: Quickly launch your app on the booted iOS simulator or Android emulator.                                                                                                                
  - **Smart Target Detection**: Automatically detects the currently booted iOS simulator to avoid targeting physical devices.
  - **Fast Reload**: Trigger a reload of the JS bundle in iOS (via AppleScript) and Android (via ADB) without leaving the app.                                                                                 
  - **Real-time Android Logs**: Stream `logcat` directly into a high-contrast, built-in console.                                                                                                               
  - **Project Selector**: Easily switch between different React Native projects.                                                                                                                               
  - **Developer Utilities**: One-click "Clear Logs" and "Copy Logs" for faster debugging.                                                                                                                      
                                                                                                                                                                                                               
  ## 🛠️  Requirements                                                                                                                                                                                           
                                                                                                                                                                                                               
  - **macOS** (Apple Silicon or Intel)                                                                                                                                                                         
  - **Xcode** & **Android Studio** installed.
  - **Node.js** & **npm/yarn** installed.                                                                                                                                                                      
  - **Android SDK Platform Tools** (adb) configured in your system path.                                                                                                                                       
                                                                                                                                                                                                               
  ## 🚀 Getting Started                                                                                                                                                                                        
                                                                                                                                                                                                               
  ### 1. Build from Source                                                                                                                                                                                     
  1. Clone this repository.
  2. Open `miniDebug.xcodeproj` in Xcode.                                                                                                                                                                      
  3. **CRITICAL**: Disable the **App Sandbox**.                                                                                                                                                                
     - Go to `Project Target` $\rightarrow$ `Signing & Capabilities`.                                                                                                                                          
     - Remove the `App Sandbox` capability entirely (click the 'X').                                                                                                                                           
     - *The app needs to execute shell commands (`npx`, `adb`, `osascript`), which is blocked by the sandbox.*                                                                                                 
  4. Run the app on your Mac.                                                                                                                                                                                  
                                                                                                                                                                                                               
  ### 2. Configure Project Path                                                                                                                                                                                
  - Once the app is running, click **Select Project** and choose the root folder of your React Native project.                                                                                                 
                                                                                                                                                                                                               
  ### 3. Grant Permissions (Required for Reload)                                                                                                                                                               
  To allow `miniDebug` to send the `Cmd + R` keystroke to the simulator:                                                                                                                                       
  1. Open **System Settings** $\rightarrow$ **Privacy & Security** $\rightarrow$ **Accessibility**.                                                                                                            
  2. Find `miniDebug` in the list and toggle the switch **ON**.                                                                                                                                                
  3. If the app is not in the list, click the `+` button and add `miniDebug.app`.                                                                                                                              
                                                                                                                                                                                                               
  ## 📖 Usage Tips                                                                                                                                                                                             
                                                                                                                                                                                                               
  ### Run iOS                                                                                                                                                                                                  
  The app automatically detects the booted simulator using `simctl`. It uses the `--no-packager` flag, so ensure you have your Metro server running in a separate terminal (`npm start`) before clicking Run.
                                                                                                                                                                                                               
  ### Android Logs                                                                                                                                                                                             
  Click **Start Android Logs** to begin streaming `logcat`. If the logs don't appear, ensure your Android device/emulator is connected via `adb devices`.                                                      
                                                                                                                                                                                                               
  ## 🛠️  How it Works                                                                                                                                                                                           
                                                                                                                                                                                                               
  - **Shell Execution**: Uses `Process` (NSTask) to run `/bin/zsh` commands.                                                                                                                                   
  - **Targeting**: Uses `xcrun simctl` to identify the active simulator and pass it to the React Native CLI.
  - **Reloading**: Uses `osascript` to tell `System Events` to simulate a keyboard shortcut in the Simulator application.                                                                                      
                                                                                                                                                                                                               
  ## 📜 License                                                                                                                                                                                                
  MIT License

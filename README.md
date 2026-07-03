# 🚀 miniDebug
 
`miniDebug` is a comprehensive macOS developer cockpit for React Native. It transforms the tedious process of managing simulators, emulators, and terminal commands into a streamlined GUI experience. Instead of juggling multiple terminal tabs and Xcode/Android Studio windows, `miniDebug` centralizes your entire development loop into one lightweight utility.
 
> ⚠️ **Under active development. Expect bugs and incomplete features as miniDebug continues to evolve.**
 
## ✨ Features
 
### 🛠️ Integrated Terminal Management
- **Metro Control Center**: Start, Kill, and Reset the Metro Bundler directly from the app. No more manual port killing or `EADDRINUSE` errors.
- **Maintenance Suite**: One-click "Deep Clean" (node_modules + build folders), "Pod Update", and "Metro Reset" (cache clear).
- **Command Transparency**: Info icons on every maintenance tool show you exactly what shell command is being executed.
### 📱 Simulator & Emulator Orchestration
- **One-Click Run**: Launch your app on the currently booted iOS simulator or Android emulator.
- **Smart Targeting**: Automatically detects the active booted iPhone simulator to avoid targeting the wrong device.
- **Instant Actions**:
    - **Reload**: Trigger JS bundle reloads via native shortcuts.
    - **Inspect**: Open the React Native Developer Menu (Dev Menu) instantly.
    - **DevTools**: Quick-launch the debugger UI in your browser.
### 🪵 Advanced Observability
- **Real-time iOS & Android Logs**: Streams the actual React Native JS log subsystem (`com.facebook.react.log`) and native fatal crashes directly into a high-contrast, built-in console — not just simulator shell noise.
- **Smart Filtering**: Real-time log filtering to find specific errors or tags instantly.
- **Log Highlighting**: Automatic color-coding based on log levels (Red for `ERROR`, Yellow for `WARN`, Blue for `INFO`).
- **Quick Utilities**: One-click "Clear" and "Copy" for fast bug reporting.
### 🐞 Automated Error Detection & Diagnosis
- **Live Error Panel**: Errors thrown in your app surface automatically in a dedicated `ERRORS` sidebar as they happen — no need to go hunting through logs.
- **Full JS Error Coverage**: Classifies every standard JS error type — `Error`, `TypeError`, `ReferenceError`, `SyntaxError`, `RangeError`, `URIError`, `AggregateError`, `EvalError` — plus React-specific issues (invalid hook calls, too many re-renders), import/module resolution failures, navigation errors, and native `FATAL EXCEPTION` crashes.
- **Exact Source Line Resolution**: Talks directly to Metro's `/symbolicate` endpoint to reverse-map compiled bundle coordinates back to your real source file and line — the same mechanism React Native's own LogBox uses — so you land on the exact line that threw, not just the component that rendered it.
- **Layered Fallback Resolution**: When an exact stack isn't available, falls back gracefully: component-stack analysis → definition-file lookup (matches the symbol to its actual source file, not just any file that mentions it) → best-effort anchor (e.g. nearest `useEffect`) — always labeled honestly in the console when a result is an approximation rather than an exact match.
- **Source Preview**: Shows the real code snippet around the resolved line directly in the error panel, styled to match what you'd see in the simulator's own redbox.
- **Open in Editor**: One click opens the exact file and line in Cursor or VS Code (auto-detected). Bundle-URL-only frames are never shown as fake-clickable — only genuinely openable local files get a button.
- **Fresh Sessions**: Error history automatically clears on every Run or Reload, so you're never staring at stale errors from a previous session.
- **AI Diagnosis (Analyze with AI)**: One-click AI-assisted root cause analysis and suggested fix for any captured error.
### 💻 Developer Experience (DX)
- **Project Intelligence**: Automatically detects the project name and current Git branch from your root folder.
- **Power-User Shortcuts**: App-level keyboard shortcuts for the most common actions (e.g., `⌘R` for Reload, `⌘D` for Inspect).
- **Environment Sanity**: Displays the current Node.js version to ensure environment consistency.
## 🛠️ Requirements
 
- **macOS** (Apple Silicon or Intel)
- **Xcode** & **Android Studio** installed.
- **Node.js** & **npm/yarn** installed.
- **Android SDK Platform Tools** (`adb`) configured in your system path.
## 🚀 Getting Started
 
### 1. Build from Source
1. Clone this repository.
2. Open `miniDebug.xcodeproj` in Xcode.
3. **CRITICAL: Disable the App Sandbox**
   - Go to `Project Target` → `Signing & Capabilities`.
   - Remove the `App Sandbox` capability entirely (click the 'X').
   - *The app must execute shell commands (`npx`, `adb`, `osascript`, `grep`, `find`), which are blocked by the macOS sandbox.*
4. Run the app on your Mac.
### 2. Configure Project Path
- Once the app is running, click **Select Project** and choose the root folder of your React Native project (the folder containing `package.json`). The app will automatically detect your project name and current Git branch. This is also the folder miniDebug searches when resolving error source locations, so make sure it points at your actual RN project root — not a subfolder like `ios/` or `android/`.
### 3. Grant Permissions (Required for Reload/Inspect)
To allow `miniDebug` to send keystrokes to the simulator:
1. Open **System Settings** → **Privacy & Security** → **Accessibility**.
2. Find `miniDebug` in the list and toggle the switch **ON**.
3. If the app is not in the list, click the `+` button and add `miniDebug.app`.
### 4. Enable Exact-Line Error Resolution (Recommended)
React Native's compact console error format doesn't always include the precise throw-site stack — only the component stack. To get exact `file:line` resolution for every error (not just an approximate component location), add this small snippet to your project's `index.js`:
 
```js
/**
 * @format
 */
import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './app.json';
 
const originalConsoleError = console.error;
console.error = (...args) => {
  const errorArg = args.find(a => a instanceof Error);
  if (errorArg && errorArg.stack) {
    originalConsoleError('FULL_STACK:', errorArg.stack);
  }
  originalConsoleError(...args);
};
 
AppRegistry.registerComponent(appName, () => App);
```
 
This intercepts `console.error` at the same point React Native's own LogBox does, forwarding the real stack trace to Metro-visible logs so miniDebug can symbolicate the exact line. Without this, miniDebug still detects and locates errors — just with component-level rather than statement-level precision.
 
## ⌨️ Keyboard Shortcuts
 
| Action | iOS | Android |
| :--- | :--- | :--- |
| **Reload Bundle** | `⌘ R` | `⌘ ⇧ R` |
| **Open Inspect Menu** | `⌘ D` | `⌘ ⇧ D` |
| **Open DevTools** | `⌘ J` | `⌘ ⇧ J` |
 
## 🛠️ How it Works
 
- **Process Orchestration**: Uses Swift's `Process` (NSTask) to execute `/bin/zsh` commands.
- **Session Management**: Tracks active PID (Process IDs) for the Metro server to allow for clean "Kill" operations without manual port hunting.
- **Dynamic Targeting**: Uses `xcrun simctl` to identify the active simulator in real-time.
- **Log Subsystem Filtering**: Streams `xcrun simctl spawn booted log stream` filtered to the `com.facebook.react.log` subsystem and native fatal exception markers, instead of generic simulator shell logs.
- **Regex-Based Classification**: A layered set of patterns (`ErrorDetector`) matches JS error types, import failures, React hook violations, navigation errors, and native crashes as log lines stream in.
- **Metro Symbolication**: Calls Metro's `/symbolicate` HTTP endpoint directly to convert compiled bundle `line:column` positions back to real source locations.
- **Heuristic Source Search**: When symbolication isn't available, falls back to targeted `grep`/`find` over the project source tree — preferring a file whose name matches the failing symbol (the actual definition) over any file that merely references it.
- **Automation**: Leverages `osascript` (AppleScript) to trigger native macOS system events for simulator control.
                                                                                                                                                                                                                                                                               
  ## 🎆 Screenshot  
 <img width="703" height="637" alt="image" src="https://github.com/user-attachments/assets/a987a2ac-f79f-4b8b-af09-c0c8f5d35952" />


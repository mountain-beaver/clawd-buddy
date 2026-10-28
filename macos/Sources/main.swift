import AppKit

// One binary, three modes:
//   ClawdBuddy hook             -> called by Claude Code hooks, forwards the event to the running app
//   ClawdBuddy make-icon <dir>  -> renders the app iconset (used by build.sh)
//   ClawdBuddy                  -> the desktop buddy itself
let args = CommandLine.arguments
if args.count > 1 && args[1] == "hook" {
    HookBridge.run()
    exit(0)
}
if args.count > 2 && args[1] == "make-icon" {
    IconMaker.run(into: args[2])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

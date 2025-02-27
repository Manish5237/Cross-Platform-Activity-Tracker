import AppKit

func getActiveBrowserTabURLAppleScriptCommand(_ appName: String) -> String? {
	switch appName {
	case "Google Chrome", "Google Chrome Beta", "Google Chrome Dev", "Google Chrome Canary", "Brave Browser", "Brave Browser Beta", "Brave Browser Nightly", "Microsoft Edge", "Microsoft Edge Beta", "Microsoft Edge Dev", "Microsoft Edge Canary", "Ghost Browser", "Wavebox", "Sidekick", "Opera":
		return "tell app \"\(appName)\" to get the URL of active tab of front window"
	case "Safari":
		return "tell app \"Safari\" to get URL of front document"
	default:
		return nil
	}
}

func exitWithoutResult() -> Never {
	print("null")
	exit(0)
}

let disableScreenRecordingPermission = CommandLine.arguments.contains("--no-screen-recording-permission")

// Show accessibility permission prompt if needed. Required to get the complete window title.
if !AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
	print("active-win requires the accessibility permission in “System Preferences › Security & Privacy › Privacy › Accessibility”.")
	exit(1)
}

// Show screen recording permission prompt if needed. Required to get the complete window title.
if !disableScreenRecordingPermission && !hasScreenRecordingPermission() {
	print("active-win requires the screen recording permission in “System Preferences › Security & Privacy › Privacy › Screen Recording”.")
	exit(1)
}

guard
	let frontmostAppPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
	let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
else {
	exitWithoutResult()
}

for window in windows {
	let windowOwnerPID = window[kCGWindowOwnerPID as String] as! pid_t // Documented to always exist.

	if windowOwnerPID != frontmostAppPID {
		continue
	}

	// Skip transparent windows, like with Chrome.
	if (window[kCGWindowAlpha as String] as! Double) == 0 { // Documented to always exist.
		continue
	}

	let bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)! // Documented to always exist.

	// Skip tiny windows, like the Chrome link hover statusbar.
	let minWinSize: CGFloat = 50
	if bounds.width < minWinSize || bounds.height < minWinSize {
		continue
	}

	// This should not fail as we're only dealing with apps, but we guard it just to be safe.
	guard let app = NSRunningApplication(processIdentifier: windowOwnerPID) else {
		continue
	}

	let appName = window[kCGWindowOwnerName as String] as? String ?? app.bundleIdentifier ?? "<Unknown>"

	let windowTitle = disableScreenRecordingPermission ? "" : window[kCGWindowName as String] as? String ?? ""

	var output: [String: Any] = [
		"title": windowTitle,
		"id": window[kCGWindowNumber as String] as! Int, // Documented to always exist.
		"bounds": [
			"x": bounds.origin.x,
			"y": bounds.origin.y,
			"width": bounds.width,
			"height": bounds.height
		],
		"owner": [
			"name": appName,
			"processId": windowOwnerPID,
			"bundleId": app.bundleIdentifier ?? "", // I don't think this could happen, but we also don't want to crash.
			"path": app.bundleURL?.path ?? "" // I don't think this could happen, but we also don't want to crash.
		],
		"memoryUsage": window[kCGWindowMemoryUsage as String] as? Int ?? 0
	]

	// Only run the AppleScript if active window is a compatible browser.
	if
		let script = getActiveBrowserTabURLAppleScriptCommand(appName),
		let url = runAppleScript(source: script)
	{
		output["url"] = url
	}

	guard let string = try? toJson(output) else {
		exitWithoutResult()
	}

	print(string)
	exit(0)
}

exitWithoutResult()

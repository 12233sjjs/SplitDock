# SplitDock

SplitDock is an early RootHide tweak prototype for iOS 16. It adds a right-edge SpringBoard handle, a radial chooser for installed apps, and a search field that launches a matching app.

## Build

The WSL build compiled the code, but its linker emitted an arm64e ABI warning and package staging failed on `/mnt/c` file permissions. For an iOS 16 arm64e target, use the included macOS GitHub Actions workflow: Theos documents the newer arm64e ABI as requiring Xcode's linker, and recommends macOS CI for developers without a Mac.

1. Create a GitHub repository with the contents of this `SplitDock` folder at the repository root.
2. Push to the default branch or run **Build SplitDock** from the repository's Actions tab.
3. Download the `SplitDock-deb` artifact from the completed workflow.

The workflow uses the RootHide Theos installer and uploads the resulting `.deb`. A successful CI build is not device runtime validation.

## Current limits

This milestone is an app launcher, not live multi-windowing. It launches the selected app normally. It does not yet embed another app's live scene, keep multiple applications interactive at once, windowize notifications, or implement window snap/expand/dismiss gestures. Those require SpringBoard/FrontBoard private scene APIs and device testing on the target jailbreak.

The tweak is filtered to SpringBoard and uses runtime selectors for LaunchServices, so iOS-version-specific behavior still needs device verification before installation.

# ResetAllKiller

A minimal rootless jailbreak tweak for **iOS 16**, inspired by the classic ResetAllKiller.

In **Settings → General → Transfer or Reset iPhone**, it greys out **Reset** and **Erase All Content and Settings**, and disables reset actions if their menu is opened. It hooks only the Settings app; there are no extra Settings pages or toggles.

Install the rootless `.deb` from [Releases](https://github.com/551UK/ResetAllKiller/releases) with Sileo or Zebra, then reopen Settings. Built with Theos for Dopamine / palera1n rootless.

**Important:** This protects the Settings interface only while jailbreak tweak injection is active. It cannot prevent a restore through a computer, recovery mode, Find My remote erase or Settings actions while booted without the jailbreak.

Source is provided for testing; the iOS 16 hooks have not yet been verified on-device.

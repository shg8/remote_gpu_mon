import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsWindow: NSWindow?
    let viewModel = GPUViewModel()

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.saveAllHistory()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        viewModel.loadNodes()
        viewModel.startAllPolling()
        viewModel.onUpdate = { [weak self] in
            self?.updateStatusBarLabel()
        }

        updateStatusBarLabel()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.image = NSImage(
                systemSymbolName: "cpu",
                accessibilityDescription: "GPU Monitor"
            )
        }
    }

    func updateStatusBarLabel() {
        guard let button = statusItem.button else { return }

        let statusBarHeight = NSStatusBar.system.thickness

        if let state = viewModel.activeNodeState,
           state.isOnline,
           let snapshot = state.latestSnapshot,
           !snapshot.gpus.isEmpty
        {
            let gpuUtils = snapshot.gpus.map(\.utilizationPercent)
            let isDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let barView = StatusBarBars(
                title: state.node.displayName,
                gpuUtils: gpuUtils,
                isDark: isDark,
                height: statusBarHeight
            )
            let renderer = ImageRenderer(content: barView)
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

            if let cgImage = renderer.cgImage {
                let scale = renderer.scale
                let image = NSImage(
                    cgImage: cgImage,
                    size: NSSize(
                        width: CGFloat(cgImage.width) / scale,
                        height: CGFloat(cgImage.height) / scale
                    )
                )
                image.isTemplate = false
                button.title = ""
                button.image = image
                button.imagePosition = .imageOnly
            }
        } else if let state = viewModel.activeNodeState {
            button.title = state.node.displayName + "\u{2009}"
            button.image = NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Offline"
            )
            button.imagePosition = .imageTrailing
        } else {
            button.title = ""
            button.image = NSImage(
                systemSymbolName: "cpu",
                accessibilityDescription: "GPU Monitor"
            )
            button.imagePosition = .imageOnly
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: Theme.Popover.width, height: Theme.Popover.height)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: GPUDetailPanel(
                viewModel: viewModel,
                onSettings: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.showSettings()
                }
            )
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure the popover's window is key so it receives keyboard events
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Settings

    func showSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(viewModel: viewModel))
            let window = NSWindow(contentViewController: controller)
            window.title = "GPU Monitor Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: Theme.Settings.width, height: Theme.Settings.idealHeight))
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

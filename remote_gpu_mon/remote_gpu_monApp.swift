//
//  remote_gpu_monApp.swift
//  remote_gpu_mon
//
//  Created by Steven on 3/2/26.
//

import SwiftUI

@main
struct remote_gpu_monApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menubar-only app — no main window.
        // Settings window is managed by AppDelegate.
        Settings { EmptyView() }
    }
}

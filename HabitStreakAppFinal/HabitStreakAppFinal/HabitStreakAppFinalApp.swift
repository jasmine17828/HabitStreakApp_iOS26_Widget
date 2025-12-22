//
//  HabitStreakAppFinalApp.swift
//  HabitStreakAppFinal
//
//  Created by 謝依晴 on 2025/12/16.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct HabitStreakAppFinalApp: App {

    private let notificationDelegate = NotificationDelegate()

    init() {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate   // ⭐ 關鍵：掛上 delegate

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // 你之後要 debug / 記錄可以放這
        }
    }

    var sharedModelContainer: ModelContainer = {
        do {
            let schema = Schema([Habit.self])
            #if DEBUG
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            #else
            let configuration = ModelConfiguration(schema: schema)
            #endif
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to load SwiftData ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

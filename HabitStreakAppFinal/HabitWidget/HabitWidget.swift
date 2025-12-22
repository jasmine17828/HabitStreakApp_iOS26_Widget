import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct HabitEntry: TimelineEntry {
    let date: Date
}

// MARK: - Timeline Provider
struct HabitProvider: TimelineProvider {

    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        completion(HabitEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let entry = HabitEntry(date: Date())

        // 每天午夜更新一次
        let nextUpdate = Calendar.current.startOfDay(for: Date().addingTimeInterval(60 * 60 * 24))
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

// MARK: - Widget View
struct HabitWidgetView: View {
    let entry: HabitEntry

    private let quotes: [String] = [
        "今天的你，比昨天更強 ✨",
        "慢慢來，比較快 🌿",
        "你正在成為自己想成為的人",
        "持續，就是你的超能力",
        "小步前進，也是在前進",
        "你已經走在正確的路上",
        "穩定前行，本身就是一種天賦",
        "為了更好的明天，今天值得努力"
    ]

    var body: some View {
        ZStack {
            // 🌫️ Liquid Glass 背景
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.45),
                                    .white.opacity(0.15),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    LinearGradient(
                        colors: glassTintColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(glassNoise)

            VStack(spacing: 16) {

                // App 名稱
                Text(Bundle.main.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.95),
                                Color.primary.opacity(0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Text(Bundle.main.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.25))
                            .blur(radius: 1.2)
                    )

                // 今日激勵語
                Text(todayQuote)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 12)

                Text("One day at a time")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .containerBackground(.clear, for: .widget)
        }
    }

    /// 每天固定一句（依日期）
    private var todayQuote: String {
        let seed = Calendar.current.ordinality(of: .day, in: .year, for: entry.date) ?? 0
        return quotes[seed % quotes.count]
    }

    private var glassTintColors: [Color] {
        let hour = Calendar.current.component(.hour, from: entry.date)

        switch hour {
        case 6..<11: // 🌅 早晨
            return [
                Color.yellow.opacity(0.18),
                Color.orange.opacity(0.14),
                Color.clear
            ]
        case 11..<17: // ☀️ 白天
            return [
                Color.pink.opacity(0.22),
                Color.orange.opacity(0.16),
                Color.clear
            ]
        default: // 🌙 夜晚
            return [
                Color.blue.opacity(0.20),
                Color.purple.opacity(0.18),
                Color.clear
            ]
        }
    }

    private var glassNoise: some View {
        Rectangle()
            .fill(
                ImagePaint(
                    image: Image(systemName: "circle.grid.3x3.fill"),
                    scale: 8
                )
            )
            .opacity(0.035)
            .blendMode(.overlay)
    }
}

// MARK: - Widget
@main
struct HabitWidget: Widget {
    let kind = "HabitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            HabitWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Motivation")
        .description("每天一句，陪你穩定前行")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Bundle Display Name Helper
extension Bundle {
    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Habit Streak"
    }
}

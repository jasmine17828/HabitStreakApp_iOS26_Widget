// HomeView.swift


import SwiftUI
import SwiftData
import Charts
import UIKit
import UserNotifications
// MARK: - 通知顯示於前景（UNUserNotificationCenterDelegate 標準解）
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // ⭐ 標準解：App 在前景也顯示通知（橫幅與聲音）
        return [.banner, .sound]
    }
}

struct BreathingCapsule: View {
    let gradient: LinearGradient
    @State private var breathe = false

    var body: some View {
        Capsule()
            .fill(gradient)
            .scaleEffect(breathe ? 1.02 : 0.98)
            .opacity(breathe ? 1.0 : 0.85)
            .animation(
                .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                value: breathe
            )
            .onAppear { breathe = true }
    }
}

struct PulsingStageIcon: View {
    let systemName: String
    let isUnlocked: Bool
    let color: Color

    @State private var appeared = false
    @State private var rotation: Double = 0
    @State private var showBurst = false

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let wave = (sin(t * 2.2) + 1) / 2           // 0~1
            let intensity = 0.6 + 0.4 * wave           // 0.6~1.0
            let glow = 6 + 14 * wave                   // 6~20

            Image(systemName: systemName)
                .font(.caption)
                .foregroundStyle(isUnlocked ? color.opacity(intensity) : .secondary.opacity(0.3))
                .scaleEffect(isUnlocked ? (appeared ? 1.15 : 0.4) : 1.0)
                .rotationEffect(.degrees(rotation))
                .opacity(isUnlocked ? 1 : 0.6)
                .shadow(
                    color: isUnlocked ? color.opacity(0.6 * intensity) : .clear,
                    radius: isUnlocked ? glow : 0
                )
                .overlay {
                    if isUnlocked {
                        Image(systemName: systemName)
                            .font(.caption)
                            .foregroundStyle(color.opacity(0.25 * intensity))
                            .blur(radius: 10 + 8 * wave)
                            .blendMode(.plusLighter)
                    }
                }
                .overlay {
                    if showBurst {
                        ParticleBurstLocal(color: color)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onChange(of: isUnlocked) { _, newValue in
                    if newValue {
                        appeared = false
                        rotation = 0
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                            appeared = true
                            rotation = 6
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeOut(duration: 0.22)) {
                                rotation = 0
                            }
                        }
                        showBurst = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showBurst = false
                            }
                        }
                    }
                }
                .onAppear {
                    if isUnlocked {
                        appeared = true
                    }
                }
        }
    }
}

struct ProgressMilestones: View {
    let progress: Double
    let symbols: [String]
    let colors: [Color]

    var body: some View {
        GeometryReader { geo in
            let ratios: [Double] = [0.2, 0.4, 0.6, 0.8, 1.0]

            ZStack(alignment: .leading) {
                ForEach(0..<ratios.count, id: \.self) { idx in
                    let x = geo.size.width * ratios[idx]
                    let unlocked = progress >= ratios[idx]

                    PulsingStageIcon(
                        systemName: symbols[idx],
                        isUnlocked: unlocked,
                        color: colors[idx]
                    )
                    .font(.system(size: 14))
                    .position(x: x, y: -10)
                }
            }
        }
    }
}

struct HabitProgressBar: View {
    let progress: Double
    let goalType: HabitGoalType

    var body: some View {
        let gradientColors: [Color] = (goalType == .count)
            ? [.blue, .green]
            : [.orange, .red]

        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(.clear)
            .background(
                Capsule().fill(Color.secondary.opacity(0.15))
            )
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width * CGFloat(max(0, min(progress, 1)))

                    ZStack(alignment: .leading) {
                        if progress >= 1.0 {
                            BreathingCapsule(
                                gradient: LinearGradient(
                                    colors: [.yellow, .orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width)
                        } else {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: width)
                        }

                        ProgressMilestones(
                            progress: progress,
                            symbols: ["sparkles", "star.fill", "flame.fill", "medal.fill", "trophy.fill"],
                            colors: [.teal, .yellow, .orange, .green, .blue]
                        )
                    }
                }
            }
            .frame(height: progress >= 1.0 ? 14 : 10)
            .animation(.easeInOut(duration: 0.4), value: progress)
    }
}

private struct ParticleBurstLocal: View {
    let color: Color
    @State private var particles: [Particle] = (0..<8).map { _ in Particle.random }

    struct Particle: Identifiable {
        let id = UUID()
        var offset: CGSize
        var size: CGFloat
        var opacity: Double

        static var random: Particle {
            Particle(
                offset: .init(width: .random(in: -18...18), height: .random(in: -18...18)),
                size: .random(in: 3...6),
                opacity: 1
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Circle()
                    .fill(color)
                    .frame(width: p.size, height: p.size)
                    .offset(p.offset)
                    .opacity(p.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                particles = particles.map { p in
                    var q = p
                    q.offset = .init(width: p.offset.width * 1.8, height: p.offset.height * 1.8)
                    q.opacity = 0
                    return q
                }
            }
        }
        .allowsHitTesting(false)
    }
}

enum ChartPeriod: String, CaseIterable, Identifiable {
    case week = "7天", month = "30天", quarter = "90天"
    var id: String { rawValue }
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

struct EarnedBadge: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt, order: .reverse) private var habits: [Habit]

    @State private var selectedPeriod: ChartPeriod = .week
    @State private var selectedHabitIDs: Set<PersistentIdentifier> = []
    @State private var punchMenuPresented = false
    @State private var punchSelectedHabitID: PersistentIdentifier? = nil
    @State private var quickPunchSelectedID: PersistentIdentifier? = nil
    @State private var showPunchSuccess = false
    @State private var punchButtonScale: CGFloat = 1.0
    @State private var bgPulse = false
    @State private var confettiBursts: [UUID] = []
    
    @State private var earnedBadge: EarnedBadge? = nil
    @State private var showBadgeCard = false
    
    @State private var lastPunchedHabitID: PersistentIdentifier? = nil
    
    private func praise(for habit: Habit) -> String {
        let s = habit.streak
        switch s {
        case 1: return "好的開始！🌟"
        case 2...3: return "保持節奏很棒！💪"
        case 4...6: return "越來越穩定！✨"
        case 7: return "一週達成！🔥"
        case 8...13: return "快到兩週了，繼續！🚀"
        default: return "太強了！已連續 \(s) 天！🏆"
        }
    }

    private func checkMilestones(for habit: Habit) -> EarnedBadge? {
        // Streak milestones
        let streakMilestones: [Int: (String, String, String)] = [
            7: ("一週達成！", "連續 7 天，太棒了！", "flame.fill"),
            14: ("雙週堅持！", "連續 14 天，繼續保持！", "flame.fill"),
            30: ("月度達成！", "連續 30 天，超強！", "trophy.fill"),
            100: ("百日傳奇！", "連續 100 天，傳說級！", "crown")
        ]
        if let info = streakMilestones[habit.streak] { return EarnedBadge(title: info.0, subtitle: info.1, symbol: info.2) }
        
        // Completion milestones
        let countMilestones: [Int: (String, String, String)] = [
            10: ("10 次完成！", "起步有力，繼續前進！", "star.fill"),
            50: ("50 次完成！", "半百堅持，值得喝采！", "medal.fill"),
            100: ("100 次完成！", "百次不易，超級堅持！", "trophy.fill")
        ]
        if let info = countMilestones[habit.completionCount] { return EarnedBadge(title: info.0, subtitle: info.1, symbol: info.2) }
        
        return nil
    }

    private func progress(for habit: Habit) -> Double {
        switch habit.goalType {
        case .count:
            if let target = habit.targetCount, target > 0 {
                return min(Double(habit.completionCount) / Double(target), 1.0)
            } else {
                return min(Double(habit.completionCount) / 10.0, 1.0)
            }
        case .date:
            guard let due = habit.dueDate else {
                return min(Double(habit.completionCount) / 10.0, 1.0)
            }
            let now = Date()
            let start = habit.createdAt
            if now >= due { return 1.0 }
            if now <= start { return 0.0 }
            let total = due.timeIntervalSince(start)
            let elapsed = now.timeIntervalSince(start)
            return max(0, min(elapsed / total, 1.0))
        }
    }

    private func stageValue(for habit: Habit) -> Int {
        switch habit.goalType {
        case .count:
            return habit.completionCount
        case .date:
            return habit.streak
        }
    }


    private func checkIns(in period: ChartPeriod, for habit: Habit) -> [Date] {
        let from = Calendar.current.date(byAdding: .day, value: -period.days + 1, to: .now)!
        return habit.checkIns.filter { $0 >= from }
    }
    
    // Inserted helpers as per instructions:
    private func chartSeries(for habits: [Habit], activeIDs: Set<PersistentIdentifier>, from: Date, calendar: Calendar) -> [(habit: Habit, items: [(day: Date, count: Int)])] {
        habits
            .filter { activeIDs.contains($0.persistentModelID) }
            .map { h in
                let dates = h.checkIns.filter { $0 >= from }
                let grouped = Dictionary(grouping: dates.map { calendar.startOfDay(for: $0) }) { $0 }
                    .mapValues { $0.count }
                let items = grouped.keys.sorted().map { (day: $0, count: grouped[$0] ?? 0) }
                return (habit: h, items: items)
            }
    }
    
    private func daysLeft(until due: Date, from now: Date = Date()) -> Int {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: now)
        let startOfDue = cal.startOfDay(for: due)
        return cal.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
    }
    
    private func remainingHoursAndMinutes(until due: Date, from now: Date = Date()) -> (hours: Int, minutes: Int) {
        let totalSecs: Int = max(0, Int(due.timeIntervalSince(now)))
        let hours: Int = totalSecs / 3600
        let minutes: Int = (totalSecs % 3600) / 60
        return (hours, minutes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    QuickPunchCard(habits: habits, modelContext: modelContext, quickPunchSelectedID: $quickPunchSelectedID, showPunchSuccess: $showPunchSuccess, punchButtonScale: $punchButtonScale, bgPulse: $bgPulse, confettiBursts: $confettiBursts, earnedBadge: $earnedBadge, showBadgeCard: $showBadgeCard, lastPunchedHabitID: $lastPunchedHabitID)
                    
                    // 1) Progress bars per habit
                    VStack(alignment: .leading, spacing: 12) {
                        Text("各任務完成狀況")
                            .font(.headline)
                        ForEach(habits) { habit in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(habit.title)
                                    Spacer()
                                    Text("\(habit.completionCount)")
                                        .foregroundStyle(.secondary)
                                }
                                let p = progress(for: habit)
                                HabitProgressBar(
                                    progress: p,
                                    goalType: habit.goalType
                                )
                                .brightness(bgPulse ? 0.1 : 0)
                                HStack(spacing: 8) {
                                    Label("已完成", systemImage: "checkmark.circle")
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(.green)
                                    Text("已完成 \(habit.completionCount) 次")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if habit.goalType == .date, let due = habit.dueDate {
                                    let dLeft = daysLeft(until: due)
                                    let remain: (hours: Int, minutes: Int) = remainingHoursAndMinutes(until: due)
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.clock").foregroundStyle(.orange)
                                        if dLeft > 0 {
                                            Text("距離目標還有 \(dLeft) 天")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text((remain.hours == 0 && remain.minutes == 0) ? "今天截止！" : "剩餘 \(remain.hours) 小時 \(remain.minutes) 分鐘")
                                                .font(.caption)
                                                .foregroundStyle((remain.hours == 0 && remain.minutes == 0) ? .red : .secondary)
                                        }
                                    }
                                }
                            }
                        }
                        if habits.isEmpty {
                            Text("目前沒有任務")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 2) Selectable time-series chart
                    VStack(alignment: .leading, spacing: 12) {
                        TrendSection(habits: habits, selectedPeriod: $selectedPeriod, selectedHabitIDs: $selectedHabitIDs)
                    }
                }
                .padding()
                .overlay(alignment: .top) {
                    PunchSuccessBanner(show: showPunchSuccess,
                                       selectedID: quickPunchSelectedID ?? habits.first?.persistentModelID,
                                       habits: habits)
                }
                .overlay {
                    ConfettiOverlay(confettiBursts: confettiBursts)
                }
                .overlay {
                    BadgeOverlay(show: showBadgeCard, earnedBadge: earnedBadge)
                }
                .background(bgPulse ? Color.green.opacity(0.08) : Color.clear)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    let name =
                        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
                        ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
                        ?? "HabitStreak"
                    Text(name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                }
            }
        }
    }
}

private struct QuickPunchCard: View {
    let habits: [Habit]
    let modelContext: ModelContext
    @Binding var quickPunchSelectedID: PersistentIdentifier?
    @Binding var showPunchSuccess: Bool
    @Binding var punchButtonScale: CGFloat
    @Binding var bgPulse: Bool
    @Binding var confettiBursts: [UUID]
    @Binding var earnedBadge: EarnedBadge?
    @Binding var showBadgeCard: Bool
    @Binding var lastPunchedHabitID: PersistentIdentifier?
    
    private func checkMilestones(for habit: Habit) -> EarnedBadge? {
        // Streak milestones
        let streakMilestones: [Int: (String, String, String)] = [
            7: ("一週達成！", "連續 7 天，太棒了！", "flame.fill"),
            14: ("雙週堅持！", "連續 14 天，繼續保持！", "flame.fill"),
            30: ("月度達成！", "連續 30 天，超強！", "trophy.fill"),
            100: ("百日傳奇！", "連續 100 天，傳說級！", "crown")
        ]
        if let info = streakMilestones[habit.streak] { return EarnedBadge(title: info.0, subtitle: info.1, symbol: info.2) }

        // Completion milestones
        let countMilestones: [Int: (String, String, String)] = [
            10: ("10 次完成！", "起步有力，繼續前進！", "star.fill"),
            50: ("50 次完成！", "半百堅持，值得喝采！", "medal.fill"),
            100: ("100 次完成！", "百次不易，超級堅持！", "trophy.fill")
        ]
        if let info = countMilestones[habit.completionCount] { return EarnedBadge(title: info.0, subtitle: info.1, symbol: info.2) }

        return nil
    }

    private func daysLeft(until due: Date, from now: Date = Date()) -> Int {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: now)
        let startOfDue = cal.startOfDay(for: due)
        return cal.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
    }

    private func remainingHoursAndMinutes(until due: Date, from now: Date = Date()) -> (hours: Int, minutes: Int) {
        let totalSecs: Int = max(0, Int(due.timeIntervalSince(now)))
        let hours: Int = totalSecs / 3600
        let minutes: Int = (totalSecs % 3600) / 60
        return (hours, minutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill").foregroundStyle(.blue)
                Text("快速打卡")
            }
            .font(.headline)
            
            let defaultID: PersistentIdentifier? = habits.first?.persistentModelID
            let chosenID: PersistentIdentifier? = quickPunchSelectedID ?? defaultID
            let selectedHabit: Habit? = habits.first(where: { $0.persistentModelID == chosenID })
            let isCount: Bool = (selectedHabit?.goalType == .count)
            let selectionBinding = Binding<PersistentIdentifier?>(get: { chosenID }, set: { newValue in
                quickPunchSelectedID = newValue
            })

            // Changed from HStack to VStack to comply with requirement for vertical layout on long names
            VStack(spacing: 12) {
                VStack(alignment: .center, spacing: 4) {
                    Text("任務：")
                        .font(.headline).bold()
                        .multilineTextAlignment(.center)
                    Picker("任務", selection: selectionBinding) {
                        ForEach(habits) { h in
                            Text(h.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .tag(Optional(h.persistentModelID))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Divider()
                if let h = selectedHabit {
                    let today = Calendar.current.startOfDay(for: Date())
                    let countToday = h.checkIns.filter { Calendar.current.startOfDay(for: $0) == today }.count
                    VStack(alignment: .center, spacing: 8) {
                        // Line 1: 今日累積（適用所有目標型態）
                        HStack(spacing: 8) {
                            Label("今日累積", systemImage: "sun.max.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.yellow)
                            Text("今日累積 \(countToday) 次")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .multilineTextAlignment(.center)
                        }

                        // Line 2: 距離目標（僅日期型顯示）
                        if h.goalType == .date, let due = h.dueDate {
                            let dLeft = daysLeft(until: due)
                            let remain: (hours: Int, minutes: Int) = remainingHoursAndMinutes(until: due)
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock").foregroundStyle(.orange)
                                if dLeft > 0 {
                                    Text("距離目標還有 \(dLeft) 天")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Text((remain.hours == 0 && remain.minutes == 0) ? "今天截止！" : "剩餘 \(remain.hours) 小時 \(remain.minutes) 分鐘")
                                        .font(.caption)
                                        .foregroundStyle((remain.hours == 0 && remain.minutes == 0) ? .red : .secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Button {
                    if let h = selectedHabit,
                       h.goalType == .count,
                       let target = h.targetCount,
                       h.completionCount >= target {

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)

                        withAnimation {
                            showPunchSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation {
                                showPunchSuccess = false
                            }
                        }
                        return
                    }
                    // Button bounce animation
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { punchButtonScale = 0.9 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { punchButtonScale = 1.0 }
                    }

                    // Perform punch-in
                    if let id = quickPunchSelectedID ?? habits.first?.persistentModelID,
                       let habit = habits.first(where: { $0.persistentModelID == id }) {
                        habit.recordCompletion()
                        try? modelContext.save()

                        // Haptic
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)

                        // Background pulse
                        withAnimation(.easeInOut(duration: 0.3)) { bgPulse = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.4)) { bgPulse = false }
                        }

                        // Success banner and confetti
                        withAnimation { showPunchSuccess = true }
                        confettiBursts.append(UUID())
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation { showPunchSuccess = false } }
                        
                        if let badge = checkMilestones(for: habit) {
                            earnedBadge = badge
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { showBadgeCard = true }
                            // stronger confetti burst
                            confettiBursts.append(UUID())
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeInOut(duration: 0.3)) { showBadgeCard = false }
                                earnedBadge = nil
                            }
                        }
                        
                        lastPunchedHabitID = habit.persistentModelID
                    }
                } label: {
                    let gradient = LinearGradient(colors: isCount ? [.blue, .green] : [.orange, .red], startPoint: .leading, endPoint: .trailing)

                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, isCount ? .green : .yellow)
                            .imageScale(.medium)
                            .rotationEffect(showPunchSuccess ? .degrees(15) : .degrees(0))
                            .animation(.easeInOut(duration: 0.2), value: showPunchSuccess)
                            .layoutPriority(1)
                        Text("CHECK!")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minWidth: 120, maxWidth: 240)
                    .background(
                        gradient,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                //.buttonStyle(.borderedProminent) // Removed as per instruction
                .disabled({
                    guard let h = selectedHabit else { return habits.isEmpty }
                    if h.goalType == .count, let target = h.targetCount {
                        return h.completionCount >= target
                    }
                    return habits.isEmpty
                }())
                .opacity({
                    guard let h = selectedHabit else { return 1 }
                    if h.goalType == .count, let target = h.targetCount {
                        return h.completionCount >= target ? 0.6 : 1
                    }
                    return 1
                }())
                .scaleEffect(punchButtonScale)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.7), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                .sensoryFeedback(.success, trigger: showPunchSuccess)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: punchButtonScale)
                .overlay(alignment: .center) {
                    if showPunchSuccess {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 8)
                            .frame(width: 60, height: 60)
                            .scaleEffect(1.4)
                            .opacity(0)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeOut(duration: 0.6), value: showPunchSuccess)
                    }
                }
            }
            
            // Persistent undo row below the punch button
            if let id = lastPunchedHabitID, let h = habits.first(where: { $0.persistentModelID == id }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.left.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("已為『\(h.title)』打卡")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("撤銷") {
                        if let idx = h.checkIns.lastIndex(where: { _ in true }) {
                            h.checkIns.remove(at: idx)
                            try? modelContext.save()
                        }
                        lastPunchedHabitID = nil
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            ZStack {
                (
                    (habits.first(where: { $0.persistentModelID == (quickPunchSelectedID ?? habits.first?.persistentModelID) })?.goalType == .count)
                    ? Color.blue.opacity(0.12)
                    : Color.orange.opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            }
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

private struct TrendSection: View {
    let habits: [Habit]
    @Binding var selectedPeriod: ChartPeriod
    @Binding var selectedHabitIDs: Set<PersistentIdentifier>

    private func chartSeries(for habits: [Habit], activeIDs: Set<PersistentIdentifier>, from: Date, calendar: Calendar) -> [(habit: Habit, items: [(day: Date, count: Int)])] {
        habits
            .filter { activeIDs.contains($0.persistentModelID) }
            .map { h in
                let dates = h.checkIns.filter { $0 >= from }
                let grouped = Dictionary(grouping: dates.map { calendar.startOfDay(for: $0) }) { $0 }
                    .mapValues { $0.count }
                let items = grouped.keys.sorted().map { (day: $0, count: grouped[$0] ?? 0) }
                return (habit: h, items: items)
            }
    }

    var body: some View {
        Text("完成趨勢")
            .font(.headline)
        HStack {
            Picker("週期", selection: $selectedPeriod) {
                ForEach(ChartPeriod.allCases) { p in Text(p.rawValue).tag(p) }
            }
            .pickerStyle(.segmented)
        }

        // Multi-select habits: simple tokens/grid of toggles
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(habits) { h in
                    let isSelected = selectedHabitIDs.contains(h.persistentModelID)
                    Button {
                        if isSelected {
                            selectedHabitIDs.remove(h.persistentModelID)
                        } else {
                            selectedHabitIDs.insert(h.persistentModelID)
                        }
                    } label: {
                        Text(h.title)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if habits.isEmpty {
            Text("請先新增任務").foregroundStyle(.secondary)
        } else {
            let activeIDs: Set<PersistentIdentifier> = {
                if selectedHabitIDs.isEmpty {
                    return Set(habits.map { $0.persistentModelID })
                } else {
                    return selectedHabitIDs
                }
            }()
            let cal: Calendar = Calendar.current
            let fromDate: Date = cal.date(byAdding: .day, value: -selectedPeriod.days + 1, to: .now)!
            let series: [(habit: Habit, items: [(day: Date, count: Int)])] = chartSeries(for: habits, activeIDs: activeIDs, from: fromDate, calendar: cal)

            Chart {
                ForEach(series, id: \.habit.persistentModelID) { s in
                    ForEach(s.items, id: \.day) { point in
                        LineMark(
                            x: .value("日期", point.day, unit: .day),
                            y: .value("次數", point.count),
                            series: .value("任務", s.habit.title)
                        )
                        PointMark(
                            x: .value("日期", point.day, unit: .day),
                            y: .value("次數", point.count)
                        )
                        .foregroundStyle(by: .value("任務", s.habit.title))
                    }
                }
            }
        }
    }
}

private struct PunchSuccessBanner: View {
    let show: Bool
    let selectedID: PersistentIdentifier?
    let habits: [Habit]
    var body: some View {
        Group {
            if show,
               let id = selectedID ?? habits.first?.persistentModelID,
               let habit = habits.first(where: { $0.persistentModelID == id }) {
                let message: String = {
                    switch habit.goalType {
                    case .count:
                        if let target = habit.targetCount, habit.completionCount >= target {
                            return "已完成目標 🎉 繼續人生新目標！"
                        } else {
                            return "已完成 \(habit.completionCount) 次！"
                        }
                    case .date:
                        return "又完成一天！🎉"
                    }
                }()
                Label(message, systemImage: habit.goalType == .count ? "checkmark.circle.fill" : "sun.max.fill")
                    .padding(10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
    }
}

private struct ConfettiOverlay: View {
    let confettiBursts: [UUID]
    var body: some View {
        ZStack {
            ForEach(confettiBursts, id: \.self) { burstID in
                ConfettiBurstView(key: burstID)
            }
        }
    }
}

private struct BadgeOverlay: View {
    let show: Bool
    let earnedBadge: EarnedBadge?
    var body: some View {
        Group {
            if show, let badge = earnedBadge {
                VStack(spacing: 8) {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 44))
                        .foregroundStyle(.yellow)
                    Text(badge.title).font(.headline)
                    Text(badge.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 12)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
    }
}

private struct ConfettiBurstView: View {
    let key: UUID
    @State private var particles: [Particle] = (0..<12).map { _ in Particle.random }
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var color: Color
        var angle: Angle
        var opacity: Double
        static var random: Particle {
            Particle(
                x: .random(in: -120...120),
                y: -40,
                size: .random(in: 6...12),
                color: [.pink, .orange, .yellow, .green, .blue, .purple].randomElement()!,
                angle: .degrees(.random(in: -30...30)),
                opacity: 1
            )
        }
    }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .rotationEffect(p.angle)
                        .position(x: geo.size.width/2 + p.x, y: p.y)
                        .opacity(p.opacity)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    particles = particles.map { p in
                        var q = p
                        q.y = geo.size.height + 20
                        q.opacity = 0
                        return q
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct NotificationSettingsView: View {
    @State private var isEnabled: Bool =
        UserDefaults.standard.bool(forKey: "notify_enabled")

    @State private var time: Date = {
        let hour = UserDefaults.standard.integer(forKey: "notify_hour")
        let minute = UserDefaults.standard.integer(forKey: "notify_minute")
        var comp = DateComponents()
        comp.hour = hour == 0 ? 9 : hour
        comp.minute = minute
        return Calendar.current.date(from: comp) ?? Date()
    }()

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $isEnabled) {
                    Label("每日激勵通知", systemImage: "bell.fill")
                }
                .onChange(of: isEnabled) { _, newValue in
                    NotificationManager.shared.update(
                        enabled: newValue,
                        hour: Calendar.current.component(.hour, from: time),
                        minute: Calendar.current.component(.minute, from: time)
                    )
                }
            }

            Section(header: Text("提醒時間")) {
                DatePicker(
                    "時間",
                    selection: $time,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .disabled(!isEnabled)
                .onChange(of: time) { _, newValue in
                    NotificationManager.shared.update(
                        enabled: isEnabled,
                        hour: Calendar.current.component(.hour, from: newValue),
                        minute: Calendar.current.component(.minute, from: newValue)
                    )
                }
            }

            Section {
                Text("開啟後會立刻收到一則激勵通知，之後每天在指定時間提醒。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("通知設定")
    }
}

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    // UserDefaults keys（與 NotificationSettingsView 對齊）
    private let enabledKey = "notify_enabled"
    private let hourKey = "notify_hour"
    private let minuteKey = "notify_minute"

    // 激勵語池
    private let messages = [
        "今天也向目標邁進一步吧 💪",
        "持續，就是你最大的超能力 ✨",
        "別小看每天的一點點努力 🌱",
        "你正在累積屬於自己的成就 🔥",
        "現在的你，比昨天更靠近目標了 🏆"
    ]

    // MARK: - Public API

    func update(enabled: Bool, hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: enabledKey)
        defaults.set(hour, forKey: hourKey)
        defaults.set(minute, forKey: minuteKey)

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        guard enabled else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    self.sendImmediateMotivation()
                    self.scheduleDaily(hour: hour, minute: minute)
                }
            } else {
                self.requestAuthorization { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.sendImmediateMotivation()
                            self.scheduleDaily(hour: hour, minute: minute)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Permission

    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            completion(granted)
        }
    }

    // MARK: - Immediate notification

    private func sendImmediateMotivation() {
        let content = UNMutableNotificationContent()
        content.title = "Habit Streak"
        content.body = messages.randomElement() ?? "開始的這一刻，就是最好的時刻 ✨"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 0.5,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "habit_immediate_motivation",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Daily schedule

    private func scheduleDaily(hour: Int, minute: Int) {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Habit Streak"
        content.body = messages.randomElement() ?? "今天也別忘了為自己打卡 🌟"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "habit_daily_motivation",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}



import SwiftUI
import SwiftData
import Charts
import SwiftDate

fileprivate extension Calendar {
    func startOfDay(_ date: Date) -> Date { self.startOfDay(for: date) }
}

fileprivate func normalized(_ date: Date) -> Date { Calendar.current.startOfDay(date) }

fileprivate func recentWindow(days: Int = 14) -> (start: Date, end: Date) {
    let cal = Calendar.current
    let end = cal.startOfDay(for: Date())
    let start = cal.date(byAdding: .day, value: -days + 1, to: end) ?? end
    return (start, end)
}

extension Habit {
    // Safely read an optional `completions: [Date]` if it exists on the model.
    fileprivate var safeCompletions: [Date] {
        // Try key-path first if the property exists at runtime
        // Fallback to Mirror-based lookup
        if let value = (Mirror(reflecting: self).children.first { $0.label == "completions" }?.value) as? [Date] {
            return value
        }
        return []
    }

    func completionRate(days: Int = 14) -> Double {
        let (start, end) = recentWindow(days: days)
        let set = Set(self.safeCompletions.map { normalized($0) })
        let count = set.filter { $0 >= start && $0 <= end }.count
        return Double(count) / Double(max(days, 1))
    }

    func dailySeries(days: Int = 14) -> [(Date, Int)] {
        let (start, end) = recentWindow(days: days)
        let set = Set(self.safeCompletions.map { normalized($0) })
        var points: [(Date, Int)] = []
        var d = start
        while d <= end {
            points.append((d, set.contains(d) ? 1 : 0))
            d = Calendar.current.date(byAdding: .day, value: 1, to: d) ?? end
        }
        return points
    }
}


struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [Habit]

    @State private var showAdd = false
    @State private var chartHabit: Habit?
    @State private var editHabit: Habit? = nil
    @State private var detailHabit: Habit? = nil

    @AppStorage("featuredHabitID") private var featuredHabitID: String = ""

    @AppStorage("habitTargetTimes") private var habitTargetTimesData: Data = Data()
    @AppStorage("habitAllDayFlags") private var habitAllDayFlagsData: Data = Data()

    private func targetKey(for habit: Habit) -> String { String(describing: habit.persistentModelID) }

    private func getTargetDate(for habit: Habit) -> Date? {
        guard let dict = try? JSONDecoder().decode([String: Date].self, from: habitTargetTimesData),
              let date = dict[targetKey(for: habit)] else { return nil }
        return date
    }

    private func setTargetDate(_ date: Date, for habit: Habit) {
        var dict: [String: Date] = (try? JSONDecoder().decode([String: Date].self, from: habitTargetTimesData)) ?? [:]
        dict[targetKey(for: habit)] = date
        if let data = try? JSONEncoder().encode(dict) { habitTargetTimesData = data }
    }

    private func getAllDay(for habit: Habit) -> Bool {
        guard let dict = try? JSONDecoder().decode([String: Bool].self, from: habitAllDayFlagsData) else { return false }
        return dict[targetKey(for: habit)] ?? false
    }

    private func setAllDay(_ allDay: Bool, for habit: Habit) {
        var dict: [String: Bool] = (try? JSONDecoder().decode([String: Bool].self, from: habitAllDayFlagsData)) ?? [:]
        dict[targetKey(for: habit)] = allDay
        if let data = try? JSONEncoder().encode(dict) { habitAllDayFlagsData = data }
    }

    private var featuredHabit: Habit? {
        habits.first(where: { String(describing: $0.persistentModelID) == featuredHabitID })
    }
    private var topHabit: Habit? { habits.max(by: { $0.completionRate() < $1.completionRate() }) }
    private var bottomHabit: Habit? { habits.min(by: { $0.completionRate() < $1.completionRate() }) }

    var body: some View {
        NavigationStack {
            List {
                // Featured section
                Section {
                    if let featured = featuredHabit {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("主任務")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("查看圖表") { chartHabit = featured }
                                    .buttonStyle(.bordered)
                            }
                            Text(featured.title)
                                .font(.title3).bold()
                            Text(featured.displayStreak)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ProgressView(value: featured.completionRate())
                                Text(String(format: "%.0f%%", featured.completionRate() * 100))
                                    .font(.footnote)
                                    .monospacedDigit()
                            }
                            if let target = getTargetDate(for: featured) {
                                Text("目標時間：\(target.toFormat("yyyy/MM/dd HH:mm")) • 還有 \(target.toRelative(since: DateInRegion()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue.opacity(0.25), .purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .background(.thinMaterial)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .purple.opacity(0.15), radius: 10, x: 0, y: 6)
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("尚未選擇主任務")
                                Spacer()
                                if !habits.isEmpty {
                                    Menu {
                                        ForEach(habits) { habit in
                                            Button(habit.title) {
                                                featuredHabitID = String(describing: habit.persistentModelID)
                                            }
                                        }
                                    } label: {
                                        Label("選擇主任務", systemImage: "chevron.down.circle")
                                    }
                                }
                            }
                            if habits.isEmpty {
                                Text("請先新增任務後再選擇主任務")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(colors: [.orange.opacity(0.18), .pink.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .background(.ultraThinMaterial)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                // Overview Chart for all habits
                if !habits.isEmpty {
                    Section("📊 各任務完成率總覽（最近14天）") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(habits) { habit in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(habit.title)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(String(format: "%.0f%%", habit.completionRate() * 100))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    ProgressView(value: habit.completionRate())
                                        .tint(.blue)
                                }
                            }
                            Text("以最近 14 天完成情況計算")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Rankings
                if let top = topHabit, let bottom = bottomHabit, habits.count > 1 {
                    Section("🏅 達成率焦點（最近14天）") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("最高")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(top.title).font(.headline)
                                Text(String(format: "%.0f%%", top.completionRate() * 100))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("需要注意")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(bottom.title).font(.headline)
                                Text(String(format: "%.0f%%", bottom.completionRate() * 100))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // List of habits
                Section("🗒️ 所有任務") {
                    ForEach(habits) { habit in
                        HStack {
                            Button(action: { detailHabit = habit }) {
                                VStack(alignment: .leading) {
                                    Text(habit.title).font(.headline)
                                    Text(habit.displayStreak).font(.subheadline)
                                    if let target = getTargetDate(for: habit) {
                                        let allDay = getAllDay(for: habit)
                                        Text(allDay ? "目標：整天（\(target.toFormat("yyyy/MM/dd"))）" : "目標時間：\(target.toFormat("yyyy/MM/dd HH:mm"))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    habit.completeToday()
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("完成", systemImage: "checkmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .green)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            Menu {
                                Button("編輯任務") { editHabit = habit }
                                Button("設為主任務") {
                                    featuredHabitID = String(describing: habit.persistentModelID)
                                }
                                if featuredHabitID == String(describing: habit.persistentModelID) {
                                    Button("取消主任務") {
                                        featuredHabitID = ""
                                    }
                                }
                                Button("查看圖表") { chartHabit = habit }
                                Button("完成明細") { detailHabit = habit }
                            } label: {
                                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Habit Streak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAdd = true }) { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddHabitInlineView { habit in
                    // Save the selected target time for this habit
                    var dict: [String: Date] = (try? JSONDecoder().decode([String: Date].self, from: habitTargetTimesData)) ?? [:]
                    dict[String(describing: habit.persistentModelID)] = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: Calendar.current.component(.minute, from: Date()), second: 0, of: Date()) ?? Date()
                    if let data = try? JSONEncoder().encode(dict) { habitTargetTimesData = data }
                }
            }
            .sheet(item: $chartHabit) { (habit: Habit) in
                HabitChartInlineView(habit: habit)
            }
            .sheet(item: $editHabit) { (habit: Habit) in
                EditHabitInlineView(habit: habit, currentTarget: getTargetDate(for: habit), currentAllDay: getAllDay(for: habit)) { newTitle, newDate, newAllDay in
                    // Update title if changed
                    if habit.title != newTitle { habit.title = newTitle }
                    // Save target date and all-day flag
                    if let date = newDate { setTargetDate(date, for: habit) } else { setTargetDate(Date(), for: habit) }
                    setAllDay(newAllDay, for: habit)
                    try? modelContext.save()
                }
            }
            .sheet(item: $detailHabit) { (habit: Habit) in
                HabitDetailInlineView(habit: habit)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(habits[index]) }
        try? modelContext.save()
    }
}
// MARK: - Simple Add Habit View placeholder (will be provided in a separate file if exists)
struct AddHabitInlineView: View {
    var onCreated: ((Habit) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title: String = ""
    @State private var targetTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("任務名稱", text: $title)
                DatePicker("預計完成目標時間", selection: $targetTime, displayedComponents: .hourAndMinute)
            }
            .navigationTitle("新增任務")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let habit = Habit(title: title)
                        modelContext.insert(habit)
                        try? modelContext.save()
                        onCreated?(habit)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HabitChartInlineView: View {
    let habit: Habit

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                let series = habit.dailySeries()
                Chart {
                    ForEach(series, id: \.0) { (date, value) in
                        LineMark(x: .value("日期", date), y: .value("完成", value))
                        PointMark(x: .value("日期", date), y: .value("完成", value))
                    }
                }
                .chartYScale(domain: 0...1)
                .frame(height: 260)
                .padding(.top)
                Text("最近 14 天完成情況")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle(habit.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct EditHabitInlineView: View {
    let habit: Habit
    var currentTarget: Date?
    var currentAllDay: Bool
    var onSave: (String, Date?, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var targetDate: Date = Date()
    @State private var isAllDay: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("名稱") {
                    TextField("任務名稱", text: $title)
                }
                Section("完成時間") {
                    Toggle("整天", isOn: $isAllDay)
                    if isAllDay {
                        DatePicker("日期", selection: $targetDate, displayedComponents: [.date])
                    } else {
                        DatePicker("日期與時間", selection: $targetDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section {
                    Button(role: .destructive) {
                        // Deletion is handled by swipe-to-delete in the list; keep placeholder or hook if needed
                        dismiss()
                    } label: {
                        Label("刪除（請在清單左滑刪除）", systemImage: "trash")
                    }
                    .disabled(true)
                }
            }
            .navigationTitle("編輯任務")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, targetDate, isAllDay)
                        dismiss()
                    }
                }
            }
            .onAppear {
                self.title = habit.title
                if let ct = currentTarget { self.targetDate = ct }
                self.isAllDay = currentAllDay
            }
        }
    }
}

struct HabitDetailInlineView: View {
    let habit: Habit
    var completions: [Date] {
        habit.safeCompletions.sorted(by: >)
    }
    var body: some View {
        NavigationStack {
            List {
                if completions.isEmpty {
                    Text("目前沒有完成紀錄")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(completions, id: \.self) { date in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(date.toFormat("yyyy/MM/dd HH:mm"))
                                .font(.body)
                            Text(date.toRelative(since: DateInRegion()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(habit.title + " 完成明細")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

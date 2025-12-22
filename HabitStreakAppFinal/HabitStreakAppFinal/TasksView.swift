import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt, order: .reverse) private var habits: [Habit]
    
    @State private var showingAdd = false
    @State private var showingEdit = false
    @State private var editingHabit: Habit? = nil
    @State private var showingDeleteAlert = false
    @State private var pendingDeleteIndexSet: IndexSet? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    NavigationLink(value: habit) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(habit.title)
                                if habit.goalType == .count {
                                    Text("次數目標")
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Capsule())
                                } else {
                                    Text("日期目標")
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                Text("\(habit.completionCount)")
                                    .foregroundStyle(.secondary)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(habit.goalType == .count ? "目標完成次數" : "目標完成時間")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if habit.goalType == .count {
                                        if let target = habit.targetCount {
                                            Text("\(target) 次")
                                        } else {
                                            Text("未設定")
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        if let due = habit.dueDate {
                                            Text(due.formatted(date: .abbreviated, time: .shortened))
                                        } else {
                                            Text("未設定")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if habit.goalType == .date, let due = habit.dueDate {
                                        let now = Date()
                                        let cal = Calendar.current
                                        let startOfNow = cal.startOfDay(for: now)
                                        let startOfDue = cal.startOfDay(for: due)
                                        let daysLeft = cal.dateComponents([.day], from: startOfNow, to: startOfDue).day ?? 0
                                        if daysLeft <= 0 {
                                            let hoursLeft = max(0, Int(due.timeIntervalSince(now) / 3600))
                                            let minutesLeft = max(0, Int((due.timeIntervalSince(now).truncatingRemainder(dividingBy: 3600)) / 60))
                                            Text(hoursLeft == 0 && minutesLeft == 0 ? "今天截止！" : "剩餘 \(hoursLeft) 小時 \(minutesLeft) 分鐘")
                                                .font(.caption2)
                                                .foregroundStyle(hoursLeft == 0 && minutesLeft == 0 ? .red : .secondary)
                                        }
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("最後完成時間")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let last = habit.lastCompletedAt {
                                        Text(last.formatted(date: .abbreviated, time: .shortened))
                                    } else {
                                        Text("尚未完成")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Gauge(value: progress(for: habit)) {
                                Text("進度")
                            } currentValueLabel: {
                                Text(String(format: "%.0f%%", progress(for: habit) * 100))
                            }
                            .gaugeStyle(.accessoryLinear)
                            .tint(LinearGradient(colors: [.blue, .purple, .pink], startPoint: .leading, endPoint: .trailing))
                            .overlay(alignment: .leading) {
                                // subtle glow at the leading edge based on progress
                                GeometryReader { geo in
                                    let width = max(0, min(1, progress(for: habit))) * geo.size.width
                                    Circle()
                                        .fill(Color.white.opacity(0.6))
                                        .blur(radius: 4)
                                        .frame(width: 8, height: 8)
                                        .offset(x: width - 6, y: (geo.size.height - 8) / 2)
                                        .opacity(progress(for: habit) > 0 ? 1 : 0)
                                        .allowsHitTesting(false)
                                }
                            }
                            .animation(.easeInOut(duration: 0.45), value: progress(for: habit))
                            .padding(.top, 2)
                            
                            let p = progress(for: habit)
                            HStack(spacing: 8) {
                                if p >= 0.25 && p < 1.0 {
                                    Label("25%", systemImage: "flag.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                        .transition(.opacity.combined(with: .scale))
                                }
                                if p >= 0.50 && p < 1.0 {
                                    Label("50%", systemImage: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                        .transition(.opacity.combined(with: .scale))
                                }
                                if p >= 0.75 && p < 1.0 {
                                    Label("75%", systemImage: "flag.checkered")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                        .transition(.opacity.combined(with: .scale))
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: p)
                            
                            if progress(for: habit) >= 1.0 {
                                Text("目標達成！🎉")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            if habit.goalType == .date {
                                HStack(spacing: 8) {
                                    Label("已完成", systemImage: "checkmark.circle")
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(.green)
                                    Text("已完成 \(habit.completionCount) 次")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if habit.goalType == .date, let target = habit.targetCount, target > 0 {
                                ProgressView(value: min(Double(habit.completionCount) / Double(target), 1.0))
                                    .progressViewStyle(.linear)
                                    .tint(.gray.opacity(0.6))
                                    .scaleEffect(x: 1, y: 0.6, anchor: .center)
                            }

                            HStack(spacing: 6) {
                                // Streak badges
                                let s = habit.streak
                                if s >= 7 { Text("🔥7") }
                                if s >= 14 { Text("🔥14") }
                                if s >= 30 { Text("🏆30") }
                                if s >= 100 { Text("👑100") }

                                // Completion count badges
                                let c = habit.completionCount
                                if c >= 10 { Text("⭐️10") }
                                if c >= 50 { Text("🎖️50") }
                                if c >= 100 { Text("🏆100") }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(
                            ZStack {
                                (habit.goalType == .count ? Color.blue.opacity(0.10) : Color.orange.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                    )
                            }
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress(for: habit))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("編輯") {
                            editingHabit = habit
                            showingEdit = true
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            if let idx = habits.firstIndex(where: { $0.persistentModelID == habit.persistentModelID }) {
                                pendingDeleteIndexSet = IndexSet(integer: idx)
                                showingDeleteAlert = true
                            }
                        } label: {
                            Label("刪除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button(role: .destructive) {
                            if let idx = habits.firstIndex(where: { $0.persistentModelID == habit.persistentModelID }) {
                                pendingDeleteIndexSet = IndexSet(integer: idx)
                                showingDeleteAlert = true
                            }
                        } label: {
                            Label("刪除", systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    pendingDeleteIndexSet = indexSet
                    showingDeleteAlert = true
                }
                .onMove(perform: move)
            }
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .navigationTitle("任務清單")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddHabitView()
            }
            .sheet(item: $editingHabit) { habit in
                NavigationStack {
                    Form {
                        TextField("名稱", text: Binding(get: { habit.title }, set: { habit.title = $0 }))
                        
                        Section("目標設定") {
                            Picker("目標類型", selection: Binding(get: { editingHabit?.goalType ?? .date }, set: { newValue in editingHabit?.goalType = newValue })) {
                                Text("次數").tag(HabitGoalType.count)
                                Text("日期").tag(HabitGoalType.date)
                            }
                            .pickerStyle(.segmented)

                            if editingHabit?.goalType == .count {
                                Stepper(value: Binding(get: { editingHabit?.targetCount ?? 10 }, set: { editingHabit?.targetCount = $0 }), in: 1...1000) {
                                    Text("目標完成次數：\(editingHabit?.targetCount ?? 10)")
                                }
                            } else {
                                DatePicker("目標時間", selection: Binding(get: { editingHabit?.dueDate ?? Date() }, set: { editingHabit?.dueDate = $0 }), displayedComponents: [.date, .hourAndMinute])
                            }
                        }
                    }
                    .navigationTitle("編輯任務")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { try? modelContext.save() }
                        }
                    }
                }
            }
            .alert("確定要刪除此任務嗎？", isPresented: $showingDeleteAlert) {
                Button("刪除", role: .destructive) {
                    if let set = pendingDeleteIndexSet {
                        delete(at: set)
                        pendingDeleteIndexSet = nil
                    }
                }
                Button("取消", role: .cancel) { pendingDeleteIndexSet = nil }
            } message: {
                if let set = pendingDeleteIndexSet, let idx = set.first, idx < habits.count {
                    Text("將刪除『\(habits[idx].title)』，此動作無法復原")
                } else {
                    Text("此動作無法復原")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(habits[index]) }
        try? modelContext.save()
    }
    
    private func move(from source: IndexSet, to destination: Int) { }
    
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
}

#Preview {
    TasksView()
}


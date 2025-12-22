import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var habit: Habit

    var body: some View {
        List {
            Section("統計") {
                LabeledContent("完成次數", value: String(habit.completionCount))
                if let last = habit.lastCompletedAt {
                    LabeledContent("最後完成", value: last.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("連續天數", value: String(habit.streak))
            }

            Section("明細") {
                if habit.checkIns.isEmpty {
                    Text("尚無打卡紀錄")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(habit.checkIns.sorted(by: >), id: \.self) { date in
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
        .navigationTitle(habit.title)
    }
}

#Preview {
    let container = try! ModelContainer(for: Habit.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let sample = Habit(title: "閱讀")
    context.insert(sample)
    return NavigationStack { HabitDetailView(habit: sample) }
        .modelContainer(container)
}

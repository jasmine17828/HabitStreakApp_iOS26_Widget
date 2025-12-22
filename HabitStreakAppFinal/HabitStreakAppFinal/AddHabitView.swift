import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @State private var title = ""
    @State private var goalType: HabitGoalType = .date
    @State private var targetCount: Int = 10
    @State private var selectedDueDate = Date()
    
    private var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        switch goalType {
        case .count:
            return targetCount > 0
        case .date:
            // due date must be later than now
            return selectedDueDate > Date()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Habit name", text: $title)
                
                Section("目標設定") {
                    Picker("目標類型", selection: $goalType) {
                        Text("次數").tag(HabitGoalType.count)
                        Text("日期").tag(HabitGoalType.date)
                    }
                    .pickerStyle(.segmented)

                    if goalType == .count {
                        Stepper(value: $targetCount, in: 1...1000) {
                            Text("目標完成次數：\(targetCount)")
                        }
                    } else {
                        DatePicker("目標時間", selection: $selectedDueDate, displayedComponents: [.date, .hourAndMinute])
                        Text(selectedDueDate <= Date() ? "目標時間必須晚於現在" : "")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let newHabit = Habit(title: trimmed)
                        newHabit.goalType = goalType
                        if goalType == .count {
                            guard targetCount > 0 else { return }
                            newHabit.targetCount = targetCount
                            newHabit.dueDate = nil
                        } else {
                            newHabit.targetCount = nil
                            newHabit.dueDate = selectedDueDate
                        }
                        modelContext.insert(newHabit)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

import WidgetKit
import SwiftUI

// 1. Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), netCalories: 0, targetCalories: 2000, remainingDays: 30, goalMode: "lose", isAchieved: false, isGoalSet: true, goalStatus: "inProgress")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), netCalories: -350, targetCalories: -500, remainingDays: 14, goalMode: "lose", isAchieved: false, isGoalSet: true, goalStatus: "inProgress")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance")
        
        let entry = SimpleEntry(
            date: Date(),
            netCalories: sharedDefaults?.double(forKey: "widget_todayNetCalories") ?? 0.0,
            targetCalories: sharedDefaults?.double(forKey: "widget_dailyTargetCalories") ?? 0.0,
            remainingDays: sharedDefaults?.integer(forKey: "widget_remainingDays") ?? 0,
            goalMode: sharedDefaults?.string(forKey: "widget_goalMode") ?? "lose",
            isAchieved: sharedDefaults?.bool(forKey: "widget_isDailyGoalAchieved") ?? false,
            isGoalSet: sharedDefaults?.bool(forKey: "isGoalSet") ?? false,
            goalStatus: sharedDefaults?.string(forKey: "widget_goalStatus") ?? "inProgress"
        )

        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// 2. Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let netCalories: Double
    let targetCalories: Double
    let remainingDays: Int
    let goalMode: String
    let isAchieved: Bool
    let isGoalSet: Bool
    let goalStatus: String
}

// 3. View
struct CalorieBalanceWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 上部：今日の収支
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(entry.netCalories <= 0 ? .green : .red)
                Text("今日の収支")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(entry.netCalories)) kcal")
                .foregroundColor(entry.netCalories <= 0 ? .green : .red)
                .font(.title)
                .bold()
                .minimumScaleFactor(0.8)
            
            Divider()
            
            // 下部：ステータスに応じた条件分岐
            if entry.isGoalSet {
                if entry.goalStatus == "achieved" {
                    Text("目標達成！")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                } else if entry.goalStatus == "expired" {
                    Text("期限が終了しました")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                } else {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("目標")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(localizedGoalMode(for: entry.goalMode)) // 翻訳を使用
                                .font(.caption)
                                .bold()
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("期限まで")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("あと \(entry.remainingDays) 日")
                                .font(.caption)
                                .bold()
                        }
                    }
                }
            } else {
                Text("目標が設定されていません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .padding(5)
    }
    
    // MARK: - Helper Methods
    private func localizedGoalMode(for mode: String) -> String {
        switch mode {
        case "lose": return String(localized: "減量")
        case "maintain": return String(localized: "維持")
        case "gain": return String(localized: "増量")
        default: return String(localized: "未設定")
        }
    }
}

// 4. Widget Configuration
struct CalorieBalanceWidget: Widget {
    let kind: String = "CalorieBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                CalorieBalanceWidgetEntryView(entry: entry)
                    .containerBackground(Color(UIColor.systemBackground), for: .widget)
            } else {
                CalorieBalanceWidgetEntryView(entry: entry)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .configurationDisplayName("カロリー収支")
        .description("今日のカロリー収支と目標を確認します。")
        .supportedFamilies([.systemSmall])
    }
}

// --- Preview ---
#Preview("1. 進行中", as: .systemSmall) {
    CalorieBalanceWidget()
} timeline: {
    SimpleEntry(date: Date(), netCalories: -200, targetCalories: -400, remainingDays: 45, goalMode: "lose", isAchieved: false, isGoalSet: true, goalStatus: "inProgress")
}

#Preview("2. 達成済み", as: .systemSmall) {
    CalorieBalanceWidget()
} timeline: {
    SimpleEntry(date: Date(), netCalories: -150, targetCalories: -400, remainingDays: 10, goalMode: "lose", isAchieved: true, isGoalSet: true, goalStatus: "achieved")
}

#Preview("3. 期限切れ（未達）", as: .systemSmall) {
    CalorieBalanceWidget()
} timeline: {
    SimpleEntry(date: Date(), netCalories: 300, targetCalories: -400, remainingDays: 0, goalMode: "lose", isAchieved: false, isGoalSet: true, goalStatus: "expired")
}

#Preview("4. 目標なし", as: .systemSmall) {
    CalorieBalanceWidget()
} timeline: {
    SimpleEntry(date: Date(), netCalories: 300, targetCalories: 0, remainingDays: 0, goalMode: "未設定", isAchieved: false, isGoalSet: false, goalStatus: "inProgress")
}

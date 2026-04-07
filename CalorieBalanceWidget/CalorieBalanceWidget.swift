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
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(entry.netCalories <= 0 ? .green : .red)
                Text(String(localized: "今日の収支"))
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            
            // 重要修正：Catalogに「%lld kcal」という一文を登録させる
            Text("\(Int(entry.netCalories)) kcal")
                .foregroundColor(entry.netCalories <= 0 ? .green : .red)
                .font(.title)
                .bold()
                .minimumScaleFactor(0.8)
            
            Divider()
            
            if entry.isGoalSet {
                if entry.goalStatus == "achieved" {
                    Text(String(localized: "目標達成！"))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                } else if entry.goalStatus == "expired" {
                    Text(String(localized: "期限が終了しました"))
                        .font(.caption)
                        .bold()
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                } else {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(String(localized: "目標"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(localizedGoalMode(for: entry.goalMode))
                                .font(.caption)
                                .bold()
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(localized: "期限まで"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            // 重要修正：バラバラにせず「あと %lld 日」という一文にする
                            // これで %@ %@ 系のゴミキーが消え、翻訳者が語順を変えられるようになります
                            Text("あと \(entry.remainingDays) 日")
                                .font(.caption)
                                .bold()
                        }
                    }
                }
            } else {
                Text(String(localized: "目標が設定されていません"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .padding(5)
    }
    
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
            // Appleの「いらんこと」への対応（iOS 17分岐）
            if #available(iOS 17.0, *) {
                CalorieBalanceWidgetEntryView(entry: entry)
                    .containerBackground(Color(UIColor.systemBackground), for: .widget)
            } else {
                CalorieBalanceWidgetEntryView(entry: entry)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .configurationDisplayName(String(localized: "カロリー収支"))
        .description(String(localized: "今日のカロリー収支と目標を確認します。"))
        .supportedFamilies([.systemSmall])
    }
}

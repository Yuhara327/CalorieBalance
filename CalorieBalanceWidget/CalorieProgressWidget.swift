import WidgetKit
import SwiftUI

// 1. Provider
struct ProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), achievementRate: 0.6, maintenanceProgress: 0.4, goalMode: "lose", remainingDays: 30, targetDiff: 5.0, isGoalSet: true, goalStatus: "inProgress")
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> ()) {
        let entry = ProgressEntry(date: Date(), achievementRate: 0.75, maintenanceProgress: 0.5, goalMode: "lose", remainingDays: 14, targetDiff: 2.5, isGoalSet: true, goalStatus: "inProgress")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance")
        
        let entry = ProgressEntry(
            date: Date(),
            achievementRate: sharedDefaults?.double(forKey: "widget_achievementRate") ?? 0.0,
            maintenanceProgress: sharedDefaults?.double(forKey: "widget_maintenanceProgress") ?? 0.0,
            goalMode: sharedDefaults?.string(forKey: "widget_goalMode") ?? "lose",
            remainingDays: sharedDefaults?.integer(forKey: "widget_remainingDays") ?? 0,
            targetDiff: sharedDefaults?.double(forKey: "widget_targetDiff") ?? 0.0,
            isGoalSet: sharedDefaults?.bool(forKey: "isGoalSet") ?? false,
            goalStatus: sharedDefaults?.string(forKey: "widget_goalStatus") ?? "inProgress"
        )
        
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// 2. Entry
struct ProgressEntry: TimelineEntry {
    let date: Date
    let achievementRate: Double
    let maintenanceProgress: Double
    let goalMode: String
    let remainingDays: Int
    let targetDiff: Double
    let isGoalSet: Bool
    let goalStatus: String
}

// 3. View
struct CalorieProgressWidgetEntryView : View {
    var entry: ProgressProvider.Entry

    var body: some View {
        if entry.isGoalSet {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                    
                    let progress = (entry.goalMode == "maintain") ? entry.maintenanceProgress : entry.achievementRate
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            ringGradient(for: entry.goalStatus),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: -2) {
                        if entry.goalStatus == "achieved" {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .foregroundColor(.green)
                        } else if entry.goalStatus == "expired" {
                            Image(systemName: "exclamationmark")
                                .font(.title2)
                                .foregroundColor(.orange)
                        } else {
                            if entry.goalMode == "maintain" {
                                // 重要修正：Catalogに「%lld 日」という一文を登録
                                Text("\(entry.remainingDays) 日")
                                    .font(.system(.title2, design: .rounded)).bold()
                            } else {
                                // 重要修正：Catalogに「%lld%」という一文を登録
                                Text("\(Int(entry.achievementRate * 100))%")
                                    .font(.system(.title2, design: .rounded)).bold()
                            }
                        }
                    }
                }
                .frame(width: 80, height: 80)
                
                statusBadge(for: entry)
            }
        } else {
            Text(String(localized: "目標未設定")).font(.caption).foregroundColor(.secondary)
        }
    }
    
    // MARK: - Subviews & Helper Methods
    
    @ViewBuilder
    private func statusBadge(for entry: ProgressEntry) -> some View {
        let message: Text = {
            if entry.goalStatus == "achieved" {
                return entry.goalMode == "maintain" ? Text(String(localized: "目標体重を維持しています！")) : Text(String(localized: "目標達成！おめでとうございます！"))
            } else if entry.goalStatus == "expired" {
                return Text(String(localized: "期限が過ぎました。再設定しましょう"))
            } else {
                // 重要修正：Measurement API で単位を自動化し、一文として構成
                let diffMeasurement = Measurement(value: entry.targetDiff, unit: UnitMass.kilograms)
                let formattedDiff = diffMeasurement.formatted(.measurement(width: .abbreviated, usage: .personWeight))
                // Catalogには「目標まであと %@」と登録され、%@ には "2.5 kg" 等が入る
                return Text("目標まであと \(formattedDiff)")
            }
        }()
        
        message
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(badgeColor(for: entry.goalStatus).opacity(0.15)))
            .foregroundColor(badgeColor(for: entry.goalStatus))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    
    private func ringGradient(for status: String) -> LinearGradient {
        switch status {
        case "achieved": return LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
        case "expired":  return LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
        default:         return LinearGradient(colors: [.teal, .cyan], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private func badgeColor(for status: String) -> Color {
        switch status {
        case "achieved": return .green
        case "expired":  return .orange
        default:         return .teal
        }
    }
}

// 4. Widget Configuration
struct CalorieProgressWidget: Widget {
    let kind: String = "CalorieProgressWidget"

    var body: some WidgetConfiguration {
        // 修正ポイント：Provider() ではなく ProgressProvider() を指定する
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            if #available(iOS 17.0, *) {
                CalorieProgressWidgetEntryView(entry: entry)
                    .containerBackground(Color(UIColor.systemBackground), for: .widget)
            } else {
                CalorieProgressWidgetEntryView(entry: entry)
                    .background(Color(UIColor.systemBackground))
            }
        }
        .configurationDisplayName(String(localized: "達成率グラフ"))
        .description(String(localized: "現在の目標達成状況をグラフで確認します。"))
        .supportedFamilies([.systemSmall])
    }
}

// --- Preview 部分 ---
#Preview("Progress Widget", as: .systemSmall) {
    CalorieProgressWidget()
} timeline: {
    ProgressEntry(
        date: Date(),
        achievementRate: 0.7,
        maintenanceProgress: 0.5,
        goalMode: "lose",
        remainingDays: 20,
        targetDiff: 3.2,
        isGoalSet: true,
        goalStatus: "inProgress"
    )
}

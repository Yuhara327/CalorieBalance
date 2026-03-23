//
//  CalorieViewModel.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//
import Foundation
import Combine
import SwiftUI

enum DietGoalMode: String, CaseIterable, Identifiable {
    case lose = "減量"
    case maintain = "維持"
    case gain = "増量"
    var id: String { self.rawValue }
    
    // アイコン名のみを定義
    var iconName: String {
        switch self {
        case .lose:     return "arrow.down.right.circle.fill"
        case .maintain: return "equal.circle.fill"
        case .gain:     return "arrow.up.right.circle.fill"
        }
    }
}
@MainActor
class CalorieBalanceViewModel: ObservableObject {
    @Published var allData: [DailyMetrics] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date = Date()
    
    //目標設定
    @AppStorage("isGoalSet") var isGoalSet: Bool = false // 目標設定がなされているか
    @AppStorage("dietGoalMode") var goalMode: DietGoalMode = .lose
    @AppStorage("targetWeight") var targetWeight: Double = 60.0
    @AppStorage("targetDateInterval") private var targetDateInterval: TimeInterval = Date().addingTimeInterval(86400 * 90).timeIntervalSince1970
    @AppStorage("startingWeight") var startingWeight: Double = 0.0
    
    enum GoalStatus {
        case inProgress
        case achieved
        case expired
    }
    
    var currentGoalStatus: GoalStatus {
        guard isGoalSet else { return .inProgress }
        
        let current = effectiveCurrentWeight
        let target = targetWeight
        let isPastDeadline = Date() > targetDate
        
        switch goalMode {
        case .maintain:
            // 維持モードの場合
            if isPastDeadline {
                // 期限が来た時に、目標との差が1kg以内なら「達成」、そうでなければ「失敗（期限切れ）」
                return abs(current - target) <= 1.0 ? .achieved : .expired
            } else {
                // 期限内であれば、今の体重に関わらず常に「進行中」
                return .inProgress
            }
            
        case .lose, .gain:
            // 減量・増量モードの場合（従来通り、目標値に達した時点で達成）
            let isWeightAchieved = (goalMode == .lose) ? (current <= target) : (current >= target)
            
            if isWeightAchieved {
                return .achieved
            } else if isPastDeadline {
                return .expired
            } else {
                return .inProgress
            }
        }
    }
    
    var remainingDays: Int {
        let calendar = Calendar.current
        // 今日の開始時点から期限日までの日数を計算
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return max(0, components.day ?? 0)
    }
    
    // 維持モード用の経過日数割合（0.0 〜 1.0）
    var maintenanceProgress: Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dietStartDate)
        let endOfDay = calendar.startOfDay(for: targetDate)
        let todayOfDay = calendar.startOfDay(for: Date())
        
        // 全体の期間（日数）
        let totalDaysComponents = calendar.dateComponents([.day], from: startOfDay, to: endOfDay)
        let totalDays = Double(totalDaysComponents.day ?? 1) // 最低1日とする
        
        // 開始日から今日までの日数
        let elapsedDaysComponents = calendar.dateComponents([.day], from: startOfDay, to: todayOfDay)
        let elapsedDays = Double(elapsedDaysComponents.day ?? 0)
        
        // 進捗率を計算（0.0 〜 1.0 にクランプ）
        return max(0.0, min(1.0, elapsedDays / totalDays))
    }
    
    var goalStatusMessage: String {
        switch currentGoalStatus {
        case .achieved:
            return goalMode == .maintain ? "目標体重を維持しています！" : "目標達成！おめでとうございます！"
        case .expired:
            return "期限が過ぎました。目標を再設定しましょう！"
        case .inProgress:
            let diff = abs(targetWeight - effectiveCurrentWeight)
            return String(format: "目標まであと%.1f kg", diff)
        }
    }
    
    var targetDate: Date {
            get { Date(timeIntervalSince1970: targetDateInterval) }
            set { targetDateInterval = newValue.timeIntervalSince1970 }
        }
    
    // 30日以内の最新の体重データを探す
    var effectiveCurrentWeight: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWeight = allData
            .filter { $0.date >= thirtyDaysAgo && $0.weight != nil}
            .last?.weight
        
        return recentWeight ?? (startingWeight > 0 ? startingWeight : targetWeight)
    }
    // 日次目標収支の計算
    var dailyTargetCalories: Double {
        let diff = targetWeight - effectiveCurrentWeight
        let totalNeededKcal = diff * 7200.0
        let days = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 1
        return totalNeededKcal/Double(max(days, 1))
    }
    // 今日の目標を達成しているかの判定
    var isDailyGoalAcheived: Bool {
        guard let todayData = allData.last(where: { Calendar.current.isDateInToday($0.date) } ),
              let net = todayData.netCalories else { return false }
        
        switch goalMode {
        case .lose: return net <= dailyTargetCalories
        case .gain: return net >= dailyTargetCalories
        case .maintain: return abs(net) <= 200
        }
    }
    
    // トータルの達成率
    var achievementRate: Double {
        guard isGoalSet, startingWeight > 0 else { return 0 }
        
        // start を「あの日決めた体重」に固定
        let start = startingWeight
        let current = effectiveCurrentWeight
        let target = targetWeight
        
        switch goalMode {
        case .lose:
            let total = start - target
            guard total > 0 else { return current <= target ? 1.0 : 0.0 }
            return min(max((start - current) / total, 0), 1)
            
        case .gain:
            let total = target - start
            guard total > 0 else { return current >= target ? 1.0 : 0.0 }
            return min(max((current - start) / total, 0), 1)
            
        case .maintain:
            // 維持モードは±1.0kg以内なら達成とみなす論理
            return abs(current - target) <= 1.0 ? 1.0 : 0.0
        }
    }
    
    // CalorieBalanceViewModel 内に追加
    func prepareForReselectingGoal() {
        // 1. 現在の(直近の)体重を開始体重として再設定
        self.startingWeight = self.effectiveCurrentWeight
        
        // 2. 期限を現在から90日後に更新（デフォルト値の再適用）
        let defaultDuration: TimeInterval = 86400 * 90
        self.targetDate = Date().addingTimeInterval(defaultDuration)
        
        // 3. (任意) 目標体重も現在の体重に近い値にリセットしたければここで調整
    }
    //開始日の「数字」は端末に保存する
    @AppStorage("dietStartDate") private var dietStartDateInterval : TimeInterval =
        Calendar.current.date(byAdding: .day, value: -29, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970 //便利な条件式である。
    //取得期間用の変数
    private var initialFetchDate: Date?
    //開始日の数字を時間型にしたり、時間型でユーザが変えたやつを数字にしたりする。つまりこいつがユーザーの設定した、ダイエットの開始日である。
    var dietStartDate: Date {
        get { Date(timeIntervalSince1970: dietStartDateInterval)}
        set { dietStartDateInterval = newValue.timeIntervalSince1970}
    }
    
    private let healthKitManager = HealthKitManager()
    
    //開始日から今日までの通算収支
    var totalNetCalories: Double {
        let starOfDay = Calendar.current.startOfDay(for: dietStartDate)
        return allData
            .filter { $0.date >= starOfDay } // ダイエット開始日以降に絞る
            .compactMap { $0.netCalories }       // netCalories が nil の要素を除外（Double? -> Double）
            .reduce(0, +)
    }
    //selectedMonthに該当するデータを抽出
    var filteredData: [DailyMetrics] {
        let calendar = Calendar.current
        return allData.filter { data in
            calendar.isDate(data.date, equalTo: selectedMonth, toGranularity: .month)
        }.sorted(by: {$0.date > $1.date})
    }
    
    func calculateWeightTrend(from startDate: Date) -> [WeightChartData] {
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        //データを日付で昇順に
        let trendData = allData
            .filter { $0.date >= startOfDay}
            .sorted { $0.date < $1.date}
        
        guard let firstValidData = trendData.first(where: { $0.weight != nil }),
              let baseWeight = firstValidData.weight else {
            return[]
        }
        
        var cumulativeNet = 0.0
        return trendData.map { data in
            if let net = data.netCalories {
                cumulativeNet += net
            }
            let predictedWeight = baseWeight + (cumulativeNet / 7200.0)
            
            return WeightChartData(date: data.date, actualWeight: data.weight, predictedWeight: predictedWeight)
        }
    }
    
    func calculateCalorieTrend(from startDate: Date) -> [CalorieChartData] {
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let trendData = allData
            .filter { $0.date >= startOfDay }
            .sorted { $0.date < $1.date }
        
        var runningSum = 0.0
        return trendData.map { data in
            let net = data.netCalories ?? 0.0
            runningSum += net
            return CalorieChartData(date: data.date, dailyNet: net, cumulativeNet: runningSum)
        }
    }
    
    func calculateSleepData(from startDate: Date) -> [SleepChartData] {
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let trendData = allData
            .filter { $0.date >= startOfDay }
            .sorted { $0.date < $1.date }
        return trendData.map { data in
            let net = data.netCalories ?? 0.0
            let sleepHours = (data.sleepSeconds ?? 0.0) / 3600.0
            
            return SleepChartData(date: data.date, sleep: sleepHours, dailyNet: net)
            
        }
    }
    
    func requestAccessAndFetchData(customStartDate: Date? = nil) {
        if isPreview { return }
        if let customStart = customStartDate, let currentOldest = initialFetchDate, customStart >= currentOldest {
                return
            }
        Task {
            isLoading = true
            let fetchStart = min(customStartDate ?? dietStartDate, initialFetchDate ?? dietStartDate)// ややこしいが、とにかくロードしなきゃいけない最古の日を記録してる
            do {
                try await healthKitManager.requestAuthorization()
                
                let fetched = try await healthKitManager.fetchDailyCalories(startDate: fetchStart, endDate: Date())
                self.allData = fetched
                self.initialFetchDate = fetchStart
            } catch {
                self.errorMessage = "データの取得に失敗しました。: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
            
            let currentOldest = initialFetchDate ?? dietStartDate
            
            if selectedMonth < currentOldest {
                let calendar = Calendar.current
                if let startOfNewMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) {
                    requestAccessAndFetchData(customStartDate: startOfNewMonth)
                }
            }
        }
    }
    
    
    
    
    //プレビューよう
    private let isPreview: Bool
    
    // 修正: イニシャライザを追加し、プレビューデータを注入できるようにする
    init(previewData: [DailyMetrics]? = nil) {
        if let data = previewData {
            // プレビューデータが渡された場合
            self.allData = data
            self.isPreview = true
            self.isLoading = false
            // プレビュー時は30日前を開始日にセットしておく
            self.dietStartDateInterval = Calendar.current.date(byAdding: .day, value: -30, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        } else {
            // 通常のアプリ起動時
            self.isPreview = false
        }
    }
}

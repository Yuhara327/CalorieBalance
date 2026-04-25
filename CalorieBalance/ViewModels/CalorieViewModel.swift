//
//  CalorieViewModel.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//
import Foundation
import Combine
import SwiftUI
import HealthKit
import WidgetKit

enum DietGoalMode: String, CaseIterable, Identifiable {
    // データベースに保存される値（rawValue）は言語に依存しない英語のキーにする
    case lose = "lose"
    case maintain = "maintain"
    case gain = "gain"
    var id: String { self.rawValue }
    
    // アプリ側のUIで表示するための翻訳プロパティを追加
    var localizedName: LocalizedStringKey {
        switch self {
        case .lose: return "lose"
        case .maintain: return "maintain"
        case .gain: return "gain"
        }
    }
    
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
    
    // 目標設定（共有領域へ保存先を変更）
    @AppStorage("isGoalSet", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var isGoalSet: Bool = false
    @AppStorage("dietGoalMode", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var goalMode: DietGoalMode = .lose
    @AppStorage("targetWeight", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var targetWeight: Double = 60.0
    @AppStorage("targetDateInterval", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) private var targetDateInterval: TimeInterval = Date().addingTimeInterval(86400 * 90).timeIntervalSince1970
    @AppStorage("startingWeight", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var startingWeight: Double = 0.0
    
    @Published var ownAppRecords: [CalorieRecord] = []
    @Published var otherAppCalories: Double = 0.0
    @Published var isDetailLoading: Bool = false
    
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
            if isPastDeadline {
                return abs(current - target) <= 1.0 ? .achieved : .expired
            } else {
                return .inProgress
            }
            
        case .lose, .gain:
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
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return max(0, components.day ?? 0)
    }
    
    var maintenanceProgress: Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dietStartDate)
        let endOfDay = calendar.startOfDay(for: targetDate)
        let todayOfDay = calendar.startOfDay(for: Date())
        
        let totalDaysComponents = calendar.dateComponents([.day], from: startOfDay, to: endOfDay)
        let totalDays = Double(totalDaysComponents.day ?? 1)
        
        let elapsedDaysComponents = calendar.dateComponents([.day], from: startOfDay, to: todayOfDay)
        let elapsedDays = Double(elapsedDaysComponents.day ?? 0)
        
        return max(0.0, min(1.0, elapsedDays / totalDays))
    }
    
    var goalStatusMessage: String {
        switch currentGoalStatus {
        case .achieved:
            return goalMode == .maintain ? String(localized: "目標体重を維持しています！") : String(localized: "目標達成！おめでとうございます！")
        case .expired:
            return String(localized: "期限が過ぎました。目標を再設定しましょう！")
        case .inProgress:
            let diff = abs(targetWeight - effectiveCurrentWeight)
            let measurement = Measurement(value: diff, unit: UnitMass.kilograms)
            let formattedDiff = measurement.formatted(.measurement(width: .abbreviated, usage: .personWeight))
            return String(localized: "目標まであと \(formattedDiff)")
        }
    }
    
    var targetDate: Date {
        get { Date(timeIntervalSince1970: targetDateInterval) }
        set { targetDateInterval = newValue.timeIntervalSince1970 }
    }
    
    var effectiveCurrentWeight: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWeight = allData
            .filter { $0.date >= thirtyDaysAgo && $0.weight != nil}
            .last?.weight
        
        return recentWeight ?? (startingWeight > 0 ? startingWeight : targetWeight)
    }
    
    var dailyTargetCalories: Double {
        let diff = targetWeight - effectiveCurrentWeight
        let totalNeededKcal = diff * 7200.0
        let days = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 1
        return totalNeededKcal/Double(max(days, 1))
    }
    
    var isDailyGoalAcheived: Bool {
        guard let todayData = allData.last(where: { Calendar.current.isDateInToday($0.date) } ),
              let net = todayData.netCalories else { return false }
        
        switch goalMode {
        case .lose: return net <= dailyTargetCalories
        case .gain: return net >= dailyTargetCalories
        case .maintain: return abs(net) <= 200
        }
    }
    
    var achievementRate: Double {
        guard isGoalSet, startingWeight > 0 else { return 0 }
        
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
            return abs(current - target) <= 1.0 ? 1.0 : 0.0
        }
    }
    
    func prepareForReselectingGoal() {
        self.startingWeight = self.effectiveCurrentWeight
        let defaultDuration: TimeInterval = 86400 * 90
        self.targetDate = Date().addingTimeInterval(defaultDuration)
    }
    
    @AppStorage("dietStartDate", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) private var dietStartDateInterval : TimeInterval =
    Calendar.current.date(byAdding: .day, value: -29, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    
    private var initialFetchDate: Date?
    
    var dietStartDate: Date {
        get { Date(timeIntervalSince1970: dietStartDateInterval)}
        set { dietStartDateInterval = newValue.timeIntervalSince1970}
    }
    
    private let healthKitManager = HealthKitManager()
    
    var totalNetCalories: Double {
        // 合計収支は常にダイエット開始日を基準とする（グラフの表示期間には影響されない）
        let startOfDay = Calendar.current.startOfDay(for: dietStartDate)
        return allData
            .filter { $0.date >= startOfDay }
            .compactMap { $0.netCalories }
            .reduce(0, +)
    }
    
    var filteredData: [DailyMetrics] {
        let calendar = Calendar.current
        return allData.filter { data in
            calendar.isDate(data.date, equalTo: selectedMonth, toGranularity: .month)
        }.sorted(by: {$0.date > $1.date})
    }
    
    // MARK: - グラフデータ計算ロジック

    func calculateWeightTrend(from startDate: Date) -> [WeightChartData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfToday = calendar.startOfDay(for: Date())
        
        var chartData: [WeightChartData] = []
        var cumulativeNet = 0.0
        
        let baseWeight = self.startingWeight > 0 ? self.startingWeight : (allData.first(where: { $0.weight != nil })?.weight ?? targetWeight)
        
        var currentDate = startOfDay
        while currentDate <= endOfToday {
            let dailyData = allData.first(where: { calendar.isDate($0.date, inSameDayAs: currentDate) })
            
            let net = dailyData?.netCalories ?? 0.0
            cumulativeNet += net
            
            let predictedWeight = baseWeight + (cumulativeNet / 7200.0)
            
            chartData.append(WeightChartData(
                date: currentDate,
                actualWeight: dailyData?.weight,
                predictedWeight: predictedWeight
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return chartData
    }
    
    func calculateCalorieTrend(from startDate: Date) -> [CalorieChartData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfToday = calendar.startOfDay(for: Date())
        
        var chartData: [CalorieChartData] = []
        var runningSum = 0.0
        
        var currentDate = startOfDay
        while currentDate <= endOfToday {
            let dailyData = allData.first(where: { calendar.isDate($0.date, inSameDayAs: currentDate) })
            
            let net = dailyData?.netCalories ?? 0.0
            runningSum += net
            
            chartData.append(CalorieChartData(
                date: currentDate,
                dailyNet: net,
                cumulativeNet: runningSum
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return chartData
    }
    
    func calculateSleepData(from startDate: Date) -> [SleepChartData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfToday = calendar.startOfDay(for: Date())
        
        var chartData: [SleepChartData] = []
        
        var currentDate = startOfDay
        while currentDate <= endOfToday {
            let dailyData = allData.first(where: { calendar.isDate($0.date, inSameDayAs: currentDate) })
            
            let net = dailyData?.netCalories ?? 0.0
            let sleepHours = (dailyData?.sleepSeconds ?? 0.0) / 3600.0
            
            chartData.append(SleepChartData(
                date: currentDate,
                sleep: sleepHours,
                dailyNet: net
            ))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return chartData
    }

    func requestAccessAndFetchData(customStartDate: Date? = nil) {
        Task {
            await reloadDataAsync(customStartDate: customStartDate)
        }
    }
    
    private func reloadDataAsync(customStartDate: Date? = nil) async {
        let dStart = self.dietStartDate
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        
        // グラフや月移動で指定された日付、もしくは前回の取得日付（異常値は除外）
        let explicitStart: Date? = {
            if let custom = customStartDate { return custom }
            if let initial = initialFetchDate, initial > Date(timeIntervalSince1970: 100000000) { return initial }
            return nil
        }()
        
        var fetchStart = thirtyDaysAgo
        if let eStart = explicitStart {
            // 指定日付、ダイエット開始日、30日前のうち、最も古い日付を採用してデータ欠損を防ぐ
            fetchStart = min(dStart, eStart, thirtyDaysAgo)
        } else {
            fetchStart = min(dStart, thirtyDaysAgo)
        }
        
        // 未来日付のガード
        if fetchStart > Date() {
            fetchStart = thirtyDaysAgo
        }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            try await healthKitManager.requestAuthorization()
            
            let calendar = Calendar.current
            let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
            
            let fetched = try await healthKitManager.fetchDailyCalories(
                startDate: fetchStart,
                endDate: endOfToday
            )
            
            await MainActor.run {
                self.allData = fetched
                self.initialFetchDate = fetchStart
                self.isLoading = false
                self.exportSnapshotForWidget()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "データの取得に失敗しました: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func refreshData() async {
        // リフレッシュ時は設定状況を再評価するため引数なしで呼ぶ
        await reloadDataAsync(customStartDate: nil)
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
    
    // MARK: - 手入力データの保存と同期
    func addDietaryCalories(_ calories: Double, for date: Date) {
            Task {
                do {
                    // 修正：時刻を12:00固定にするのではなく、現在時刻を合成する
                    let now = Date()
                    let calendar = Calendar.current
                    
                    // 表示中の日付(年・月・日)に、現在の(時・分・秒)を組み合わせる
                    let components = calendar.dateComponents([.hour, .minute, .second], from: now)
                    let saveDate = calendar.date(bySettingHour: components.hour ?? 12,
                                               minute: components.minute ?? 0,
                                               second: components.second ?? 0,
                                               of: date) ?? date
                    
                    try await healthKitManager.saveDietaryEnergy(calories: calories, date: saveDate)
                    
                    // HealthKitへの書き込み反映を待機
                    try await Task.sleep(nanoseconds: 500_000_000)
                    
                    // データの再取得
                    await reloadDataAsync(customStartDate: initialFetchDate)
                    await MainActor.run {
                        self.loadCalorieDetails(for: date)
                    }
                    
                } catch {
                    await MainActor.run { self.errorMessage = "カロリーの保存に失敗: \(error.localizedDescription)" }
                }
            }
        }
    func addWeight(_ weight: Double, for date: Date) {
            Task {
                do {
                    // 1. まず、その日の既存の自アプリ入力データを削除（上書きの準備）
                    try await healthKitManager.deleteQuantityData(for: .bodyMass, on: date)
                    
                    // 2. 新しいデータを保存
                    let saveDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
                    try await healthKitManager.saveWeight(weight: weight, date: saveDate)
                    
                    // 3. HealthKitへの反映待機とリロード
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await reloadDataAsync(customStartDate: initialFetchDate)
                } catch {
                    await MainActor.run { self.errorMessage = "体重の保存に失敗: \(error.localizedDescription)" }
                }
            }
        }
    func addSleep(start: Date, end: Date, targetDate: Date) {
            // バリデーション（既存のまま）
            let now = Date()
            guard end <= now, Calendar.current.isDate(end, inSameDayAs: targetDate),
                  start < end, end.timeIntervalSince(start) <= 86400 else { return }
            
            Task {
                do {
                    // 1. その日の既存の睡眠データを削除
                    try await healthKitManager.deleteSleepData(on: targetDate)
                    
                    // 2. 新しい睡眠期間を保存
                    try await healthKitManager.saveSleep(start: start, end: end)
                    
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await reloadDataAsync(customStartDate: initialFetchDate)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "睡眠の保存に失敗しました: \(error.localizedDescription)"
                    }
                }
            }
        }
    // MARK: - 手入力データの削除
    
    func deleteDietaryCalories(for date: Date) {
            Task {
                do {
                    // 1. 指定した日の自アプリデータを一括削除
                    try await healthKitManager.deleteQuantityData(for: .dietaryEnergyConsumed, on: date)
                    
                    // 2. HealthKitの反映を待機
                    try await Task.sleep(nanoseconds: 500_000_000)
                    
                    // 3. 全体データの更新（グラフ等のため）
                    await reloadDataAsync(customStartDate: initialFetchDate)
                    
                    // 4. 追加：個別詳細リストの更新（ここが重要）
                    await MainActor.run {
                        self.loadCalorieDetails(for: date)
                    }
                } catch {
                    await MainActor.run { self.errorMessage = "カロリーの削除に失敗: \(error.localizedDescription)" }
                }
            }
        }
    func deleteWeight(for date: Date) {
        Task {
            do {
                try await healthKitManager.deleteQuantityData(for: .bodyMass, on: date)
                try await Task.sleep(nanoseconds: 500_000_000)
                await reloadDataAsync(customStartDate: initialFetchDate)
            } catch {
                await MainActor.run { self.errorMessage = "体重の削除に失敗: \(error.localizedDescription)" }
            }
        }
    }
    
    func deleteSleep(for date: Date) {
        Task {
            do {
                try await healthKitManager.deleteSleepData(on: date)
                try await Task.sleep(nanoseconds: 500_000_000)
                await reloadDataAsync(customStartDate: initialFetchDate)
            } catch {
                await MainActor.run { self.errorMessage = "睡眠の削除に失敗: \(error.localizedDescription)" }
            }
        }
    }
    
    private let isPreview: Bool
    
    init(previewData: [DailyMetrics]? = nil) {
        if let data = previewData {
            self.allData = data
            self.isPreview = true
            self.isLoading = false
            self.dietStartDateInterval = Calendar.current.date(byAdding: .day, value: -30, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        } else {
            self.isPreview = false
        }
    }
    
    // MARK: - Widget連携用データの書き出し
    private func exportSnapshotForWidget() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance") else { return }
        
        let todayData = allData.first(where: { Calendar.current.isDateInToday($0.date) })
        
        let progress = (goalMode == .maintain) ? maintenanceProgress : achievementRate
        sharedDefaults.set(progress, forKey: "widget_progressRate")
        
        let statusString: String
        switch currentGoalStatus {
        case .inProgress: statusString = "inProgress"
        case .achieved:   statusString = "achieved"
        case .expired:    statusString = "expired"
        }
        
        sharedDefaults.set(statusString, forKey: "widget_goalStatus")
        sharedDefaults.set(todayData?.netCalories ?? 0.0, forKey: "widget_todayNetCalories")
        sharedDefaults.set(dailyTargetCalories, forKey: "widget_dailyTargetCalories")
        sharedDefaults.set(achievementRate, forKey: "widget_achievementRate")
        sharedDefaults.set(remainingDays, forKey: "widget_remainingDays")
        sharedDefaults.set(isDailyGoalAcheived, forKey: "widget_isDailyGoalAchieved")
        sharedDefaults.set(goalMode.rawValue, forKey: "widget_goalMode")
        let diff = abs(targetWeight - effectiveCurrentWeight)
        sharedDefaults.set(diff, forKey: "widget_targetDiff")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension CalorieBalanceViewModel {
    var userWeightUnit: UnitMass {
        let system = Locale.current.measurementSystem
        if system == .us { return .pounds }
        if system == .uk { return .stones }
        return .kilograms
    }

    func saveWeightFromUserUnit(_ value: Double, for date: Date) {
        let measurement = Measurement(value: value, unit: userWeightUnit)
        let kgValue = measurement.converted(to: .kilograms).value
        self.addWeight(kgValue, for: date)
    }
    
    func convertToUserUnitValue(_ kgValue: Double) -> Double {
        let measurement = Measurement(value: kgValue, unit: UnitMass.kilograms)
        return measurement.converted(to: userWeightUnit).value
    }
}
// MARK: - 個別カロリー記録（詳細リスト）用ロジック
extension CalorieBalanceViewModel {
    
    // UIを構築するための状態変数（Viewで展開するために@Publishedは不要な場合もありますが、ViewModel内に置くなら@Publishedにします）
    // 追記: クラスのトップレベルに以下の3つを定義してください
    /*
    @Published var ownAppRecords: [CalorieRecord] = []
    @Published var otherAppCalories: Double = 0.0
    @Published var isDetailLoading: Bool = false
    */
    
    /// 指定された日のカロリー詳細を取得し、自アプリと他アプリに振り分けます
    func loadCalorieDetails(for date: Date) {
        Task {
            await MainActor.run { self.isDetailLoading = true }
            
            do {
                let records = try await healthKitManager.fetchDailyCalorieRecords(for: date)
                
                await MainActor.run {
                    // 自アプリのデータはリスト表示用に保持
                    self.ownAppRecords = records.filter { $0.isOwnApp }
                    
                    // 他アプリのデータは合計値（Double）として合算
                    self.otherAppCalories = records
                        .filter { !$0.isOwnApp }
                        .reduce(0) { $0 + $1.calories }
                    
                    self.isDetailLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "詳細データの取得に失敗しました: \(error.localizedDescription)"
                    self.isDetailLoading = false
                }
            }
        }
    }
    
    /// SwiftUIの .onDelete から呼ばれる削除処理
    func deleteCalorieRecord(at offsets: IndexSet, for date: Date) {
        // IndexSetから削除対象のCalorieRecordを特定
        let recordsToDelete = offsets.map { ownAppRecords[$0] }
        
        Task {
            do {
                // 1. HealthKitから対象データを個別に削除
                for record in recordsToDelete {
                    try await healthKitManager.deleteCalorieRecord(record)
                }
                
                // 2. HealthKitのデータベース同期を待機
                try await Task.sleep(nanoseconds: 500_000_000)
                
                // 3. データの再取得（詳細リストの更新 ＆ 全体グラフの更新）
                self.loadCalorieDetails(for: date)
                await self.reloadDataAsync(customStartDate: self.initialFetchDate)
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "カロリーの削除に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
}

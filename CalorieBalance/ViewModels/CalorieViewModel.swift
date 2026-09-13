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
    case lose = "lose"
    case maintain = "maintain"
    case gain = "gain"
    var id: String { self.rawValue }
    
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
    
    // --- 永続化プロパティ (AppStorage) ---
    @AppStorage("isGoalSet", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var isGoalSet: Bool = false
    @AppStorage("dietGoalMode", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var goalMode: DietGoalMode = .lose
    @AppStorage("targetWeight", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var targetWeight: Double = 60.0
    @AppStorage("startingWeight", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var startingWeight: Double = 0.0
    
    // ※ targetDateInterval, goalStartDateInterval, graphDisplayStartDateInterval の @AppStorage は
    // SwiftUIの同期バグを回避するため削除し、下の Computed Properties で直接 UserDefaults を操作します。

    // 詳細画面用
    @Published var ownAppRecords: [CalorieRecord] = []
    @Published var otherAppCalories: Double = 0.0
    @Published var isDetailLoading: Bool = false
    
    // --- Computed Properties (Date) ---
    var goalStartDate: Date {
        get {
            let interval = UserDefaults(suiteName: "group.yuhara.CalorieBalance")?.double(forKey: "goalStartDateInterval") ?? 0
            return interval > 0 ? Date(timeIntervalSince1970: interval) : Date()
        }
        set {
            objectWillChange.send()
            UserDefaults(suiteName: "group.yuhara.CalorieBalance")?.set(newValue.timeIntervalSince1970, forKey: "goalStartDateInterval")
        }
    }

    var graphDisplayStartDate: Date {
        get {
            let defaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance")
            let interval = defaults?.double(forKey: "graphDisplayStartDateInterval") ?? 0
            if interval > 0 {
                return Date(timeIntervalSince1970: interval)
            } else {
                let defaultDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
                // 初回アクセス時に明示的に初期値をディスクへ保存し、固定化する
                defaults?.set(defaultDate.timeIntervalSince1970, forKey: "graphDisplayStartDateInterval")
                return defaultDate
            }
        }
        set {
            objectWillChange.send()
            UserDefaults(suiteName: "group.yuhara.CalorieBalance")?.set(newValue.timeIntervalSince1970, forKey: "graphDisplayStartDateInterval")
        }
    }

    var targetDate: Date {
        get {
            let interval = UserDefaults(suiteName: "group.yuhara.CalorieBalance")?.double(forKey: "targetDateInterval") ?? 0
            return interval > 0 ? Date(timeIntervalSince1970: interval) : Date().addingTimeInterval(86400 * 90)
        }
        set {
            objectWillChange.send()
            UserDefaults(suiteName: "group.yuhara.CalorieBalance")?.set(newValue.timeIntervalSince1970, forKey: "targetDateInterval")
        }
    }

    // --- 目標ステータス・進捗 ---
    enum GoalStatus {
        case inProgress, achieved, expired
    }
    
    var currentGoalStatus: GoalStatus {
        guard isGoalSet else { return .inProgress }
        let current = effectiveCurrentWeight
        let isPastDeadline = Date() > targetDate
        
        switch goalMode {
        case .maintain:
            if isPastDeadline { return abs(current - targetWeight) <= 1.0 ? .achieved : .expired }
            return .inProgress
        case .lose, .gain:
            let achieved = (goalMode == .lose) ? (current <= targetWeight) : (current >= targetWeight)
            if achieved { return .achieved }
            return isPastDeadline ? .expired : .inProgress
        }
    }
    
    var remainingDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: targetDate))
        return max(0, components.day ?? 0)
    }
    
    var maintenanceProgress: Double {
        let calendar = Calendar.current
        let total = calendar.dateComponents([.day], from: calendar.startOfDay(for: goalStartDate), to: calendar.startOfDay(for: targetDate)).day ?? 1
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: goalStartDate), to: calendar.startOfDay(for: Date())).day ?? 0
        return max(0.0, min(1.0, Double(elapsed) / Double(total)))
    }
    
    var achievementRate: Double {
        guard isGoalSet, startingWeight > 0 else { return 0 }
        let start = startingWeight
        let current = effectiveCurrentWeight
        let target = targetWeight
        
        switch goalMode {
        case .lose:
            let total = start - target
            return total > 0 ? min(max((start - current) / total, 0), 1) : (current <= target ? 1.0 : 0.0)
        case .gain:
            let total = target - start
            return total > 0 ? min(max((current - start) / total, 0), 1) : (current >= target ? 1.0 : 0.0)
        case .maintain:
            return abs(current - target) <= 1.0 ? 1.0 : 0.0
        }
    }
    
    var goalStatusMessage: String {
        switch currentGoalStatus {
        case .achieved: return goalMode == .maintain ? String(localized: "目標体重を維持しています！") : String(localized: "目標達成！おめでとうございます！")
        case .expired: return String(localized: "期限が過ぎました。目標を再設定しましょう！")
        case .inProgress:
            let diff = abs(targetWeight - effectiveCurrentWeight)
            let formattedDiff = Measurement(value: diff, unit: UnitMass.kilograms).formatted(.measurement(width: .abbreviated, usage: .personWeight))
            return String(localized: "目標まであと \(formattedDiff)")
        }
    }

    var effectiveCurrentWeight: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentWeight = allData.filter { $0.date >= thirtyDaysAgo && $0.weight != nil }.last?.weight
        return recentWeight ?? (startingWeight > 0 ? startingWeight : targetWeight)
    }
    
    var dailyTargetCalories: Double {
        let diff = targetWeight - effectiveCurrentWeight
        let days = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 1
        return (diff * 7200.0) / Double(max(days, 1))
    }
    
    var isDailyGoalAcheived: Bool {
        guard let todayData = allData.last(where: { Calendar.current.isDateInToday($0.date) }), let net = todayData.netCalories else { return false }
        switch goalMode {
        case .lose: return net <= dailyTargetCalories
        case .gain: return net >= dailyTargetCalories
        case .maintain: return abs(net) <= 200
        }
    }

    // --- 合計収支計算 (分離) ---
    var goalTotalNetCalories: Double {
        let startOfDay = Calendar.current.startOfDay(for: goalStartDate)
        return allData.filter { $0.date >= startOfDay }.compactMap { $0.netCalories }.reduce(0, +)
    }
    
    var graphTotalNetCalories: Double {
        let startOfDay = Calendar.current.startOfDay(for: graphDisplayStartDate)
        return allData.filter { $0.date >= startOfDay }.compactMap { $0.netCalories }.reduce(0, +)
    }

    // --- Data Fetching ---
    private let healthKitManager = HealthKitManager()
    private var initialFetchDate: Date?

    func requestAccessAndFetchData(customStartDate: Date? = nil) {
        Task { await reloadDataAsync(customStartDate: customStartDate) }
    }
    
    private func reloadDataAsync(customStartDate: Date? = nil) async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        let fetchStart = min(goalStartDate, graphDisplayStartDate, thirtyDaysAgo, customStartDate ?? Date())
        
        await MainActor.run { self.isLoading = true }
        do {
            try await healthKitManager.requestAuthorization()
            
            healthKitManager.startObservingDietaryEnergyChanges { [weak self] in
                   Task { @MainActor [weak self] in
                       await self?.refreshData()
                   }
               }
            
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())

            guard let endOfToday = calendar.date(
                byAdding: .day,
                value: 1,
                to: startOfToday
            ) else {
                return
            }

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
            await MainActor.run { self.errorMessage = error.localizedDescription; self.isLoading = false }
        }
    }
    
    func refreshData() async { await reloadDataAsync(customStartDate: initialFetchDate) }
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }

    var filteredData: [DailyMetrics] {
        allData.filter { metrics in
            Calendar.current.isDate(metrics.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    // --- Trend Graph Calculation ---
    func calculateWeightTrend(from startDate: Date) -> [WeightChartData] {
            let calendar = Calendar.current
            var chartData: [WeightChartData] = []
            
            let startOfDay = calendar.startOfDay(for: startDate)
            let periodData = allData.filter { $0.date >= startOfDay }
            
            // 1. 期間内の最初の体重計測データ（アンカーポイント）を探す
            let anchorPoint = periodData.first(where: { $0.weight != nil })
            
            let baseWeight: Double
            
            if let anchor = anchorPoint, let anchorWeight = anchor.weight {
                // アンカーポイントが存在する場合
                // 開始日からアンカー日までの累積カロリーを計算し、開始日時点での「理論上の初期体重（y切片）」を逆算する。
                // これにより、予測線のプロットがアンカーポイントの実測値と完全に交差する。
                let caloriesUpToAnchor = periodData
                    .filter { $0.date <= anchor.date }
                    .compactMap { $0.netCalories }
                    .reduce(0, +)
                
                baseWeight = anchorWeight - (caloriesUpToAnchor / 7200.0)
            } else {
                // 2. 期間内に計測が1日もない場合のフォールバック（仮置き）
                // 優先順位: 期間以前の最新の体重 -> 初期設定体重(startingWeight) -> 任意の仮置き数値(60.0kg)
                // ※ターゲット体重は目標値に過ぎず、現在地の仮置きとしては不適なため排除。
                let pastWeight = allData.filter { $0.date < startOfDay && $0.weight != nil }.last?.weight
                baseWeight = pastWeight ?? (startingWeight > 0 ? startingWeight : 60.0)
            }

            // 3. 配列の生成と予測値のプロット
            var cumulativeNet = 0.0
            var current = startOfDay
            while current <= calendar.startOfDay(for: Date()) {
                let daily = allData.first(where: { calendar.isDate($0.date, inSameDayAs: current) })
                cumulativeNet += daily?.netCalories ?? 0.0
                
                chartData.append(WeightChartData(
                    date: current,
                    actualWeight: daily?.weight,
                    predictedWeight: baseWeight + (cumulativeNet / 7200.0)
                ))
                
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }
            
            return chartData
        }

    func calculateCalorieTrend(from startDate: Date) -> [CalorieChartData] {
        let calendar = Calendar.current
        var chartData: [CalorieChartData] = []
        var runningSum = 0.0
        var current = calendar.startOfDay(for: startDate)
        while current <= calendar.startOfDay(for: Date()) {
            let daily = allData.first(where: { calendar.isDate($0.date, inSameDayAs: current) })
            let net = daily?.netCalories ?? 0.0
            runningSum += net
            chartData.append(CalorieChartData(date: current, dailyNet: net, cumulativeNet: runningSum))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return chartData
    }

    func calculateSleepData(from startDate: Date) -> [SleepChartData] {
        let calendar = Calendar.current
        var chartData: [SleepChartData] = []
        var current = calendar.startOfDay(for: startDate)
        while current <= calendar.startOfDay(for: Date()) {
            let daily = allData.first(where: { calendar.isDate($0.date, inSameDayAs: current) })
            chartData.append(SleepChartData(date: current, sleep: (daily?.sleepSeconds ?? 0) / 3600.0, dailyNet: daily?.netCalories ?? 0))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return chartData
    }

    // --- 手入力保存 (Upsert) ---
    func addDietaryCalories(_ calories: Double, for date: Date) {
        Task {
            do {
                let calendar = Calendar.current

                // カロリーは時刻ではなく「その日の摂取量」として扱う。
                // 日付境界問題を避けるため12:00に正規化する。
                let saveDate = calendar.date(
                    bySettingHour: 12,
                    minute: 0,
                    second: 0,
                    of: date
                ) ?? date

                try await healthKitManager.saveDietaryEnergy(
                    calories: calories,
                    date: saveDate
                )

                await refreshData()

                await MainActor.run {
                    self.loadCalorieDetails(for: date)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func addWeight(_ weight: Double, for date: Date) {
        Task {
            do {
                try await healthKitManager.deleteQuantityData(for: .bodyMass, on: date)
                try await healthKitManager.saveWeight(weight: weight, date: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
                try await Task.sleep(nanoseconds: 500_000_000)
                await refreshData()
            } catch { await MainActor.run { self.errorMessage = error.localizedDescription } }
        }
    }

    func addSleep(start: Date, end: Date, targetDate: Date) {
        guard end <= Date(), Calendar.current.isDate(end, inSameDayAs: targetDate), start < end, end.timeIntervalSince(start) <= 86400 else { return }
        Task {
            do {
                try await healthKitManager.deleteSleepData(on: targetDate)
                try await healthKitManager.saveSleep(start: start, end: end)
                try await Task.sleep(nanoseconds: 500_000_000)
                await refreshData()
            } catch { await MainActor.run { self.errorMessage = error.localizedDescription } }
        }
    }

    // --- 削除・リセット ---
    func deleteDietaryCalories(for date: Date) {
        Task {
            do {
                try await healthKitManager.deleteQuantityData(for: .dietaryEnergyConsumed, on: date)
                try await Task.sleep(nanoseconds: 500_000_000)
                await refreshData()
                await MainActor.run { self.loadCalorieDetails(for: date) }
            } catch { await MainActor.run { self.errorMessage = error.localizedDescription } }
        }
    }

    func deleteCalorieRecord(at offsets: IndexSet, for date: Date) {
        let recordsToDelete = offsets.map { ownAppRecords[$0] }
        Task {
            do {
                for record in recordsToDelete { try await healthKitManager.deleteCalorieRecord(record) }
                try await Task.sleep(nanoseconds: 500_000_000)
                await refreshData()
                await MainActor.run { self.loadCalorieDetails(for: date) }
            } catch { await MainActor.run { self.errorMessage = error.localizedDescription } }
        }
    }

    func deleteWeight(for date: Date) {
        Task {
            do {
                try await healthKitManager.deleteQuantityData(for: .bodyMass, on: date)
                try await Task.sleep(nanoseconds: 500_000_000)
                await refreshData()
            } catch { await MainActor.run { self.errorMessage = error.localizedDescription } }
        }
    }

    func deleteSleep(for date: Date) {
        Task {
            do {
                try await healthKitManager.deleteSleepData(on: date)
                try await Task.sleep(nanoseconds: 500_000_000)
                await refreshData()
            } catch { await MainActor.run { self.errorMessage = error.localizedDescription } }
        }
    }

    func loadCalorieDetails(for date: Date) {
        Task {
            await MainActor.run { self.isDetailLoading = true }
            do {
                let records = try await healthKitManager.fetchDailyCalorieRecords(for: date)
                await MainActor.run {
                    self.ownAppRecords = records.filter { $0.isOwnApp }
                    self.otherAppCalories = records.filter { !$0.isOwnApp }.reduce(0) { $0 + $1.calories }
                    self.isDetailLoading = false
                }
            } catch { await MainActor.run { self.errorMessage = error.localizedDescription; self.isDetailLoading = false } }
        }
    }

    func prepareForReselectingGoal() {
        self.startingWeight = self.effectiveCurrentWeight
        self.targetDate = Date().addingTimeInterval(86400 * 90)
        self.goalStartDate = Date()
        self.graphDisplayStartDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    }

    // --- 初期化・Utility ---
    private let isPreview: Bool
    init(previewData: [DailyMetrics]? = nil) {
        if let data = previewData {
            self.allData = data
            self.isPreview = true
            self.isLoading = false
        } else {
            self.isPreview = false
        }
    }

    var userWeightUnit: UnitMass {
        let system = Locale.current.measurementSystem
        if system == .us { return .pounds }
        if system == .uk { return .stones }
        return .kilograms
    }

    func saveWeightFromUserUnit(_ value: Double, for date: Date) {
        let kgValue = Measurement(value: value, unit: userWeightUnit).converted(to: .kilograms).value
        self.addWeight(kgValue, for: date)
    }
    
    func convertToUserUnitValue(_ kgValue: Double) -> Double {
        return Measurement(value: kgValue, unit: UnitMass.kilograms).converted(to: userWeightUnit).value
    }

    private func exportSnapshotForWidget() {
        guard let sd = UserDefaults(suiteName: "group.yuhara.CalorieBalance") else { return }
        let today = allData.first(where: { Calendar.current.isDateInToday($0.date) })
        let progress = (goalMode == .maintain) ? maintenanceProgress : achievementRate
        sd.set(progress, forKey: "widget_progressRate")
        sd.set(today?.netCalories ?? 0.0, forKey: "widget_todayNetCalories")
        sd.set(dailyTargetCalories, forKey: "widget_dailyTargetCalories")
        sd.set(achievementRate, forKey: "widget_achievementRate")
        sd.set(remainingDays, forKey: "widget_remainingDays")
        sd.set(isDailyGoalAcheived, forKey: "widget_isDailyGoalAchieved")
        sd.set(goalMode.rawValue, forKey: "widget_goalMode")
        sd.set(abs(targetWeight - effectiveCurrentWeight), forKey: "widget_targetDiff")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

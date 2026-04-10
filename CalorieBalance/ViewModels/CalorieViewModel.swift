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
    
#if DEBUG
    // デモデータが注入されたかどうかの判定フラグ
    @AppStorage("isDemoMode", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var isDemoMode: Bool = false
#endif
    
    // 目標設定（共有領域へ保存先を変更）
    @AppStorage("isGoalSet", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var isGoalSet: Bool = false
    @AppStorage("dietGoalMode", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var goalMode: DietGoalMode = .lose
    @AppStorage("targetWeight", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var targetWeight: Double = 60.0
    @AppStorage("targetDateInterval", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) private var targetDateInterval: TimeInterval = Date().addingTimeInterval(86400 * 90).timeIntervalSince1970
    @AppStorage("startingWeight", store: UserDefaults(suiteName: "group.yuhara.CalorieBalance")) var startingWeight: Double = 0.0
    
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
        let starOfDay = Calendar.current.startOfDay(for: dietStartDate)
        return allData
            .filter { $0.date >= starOfDay }
            .compactMap { $0.netCalories }
            .reduce(0, +)
    }
    
    var filteredData: [DailyMetrics] {
        let calendar = Calendar.current
        return allData.filter { data in
            calendar.isDate(data.date, equalTo: selectedMonth, toGranularity: .month)
        }.sorted(by: {$0.date > $1.date})
    }
    
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
#if DEBUG
        // デモモード時はHealthKitへのアクセス自体を遮断する
        if isDemoMode { return }
#endif
        
        let fetchStart = customStartDate ?? initialFetchDate ?? dietStartDate
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
#if DEBUG
                // 非同期処理中にデモデータが注入された場合の上書き防止
                if self.isDemoMode { return }
#endif
                
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
        await reloadDataAsync()
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
    
    func addDietaryCalories(_ calories: Double, for date: Date) {
        Task {
            do {
                let saveDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
                try await healthKitManager.saveDietaryEnergy(calories: calories, date: saveDate)
                try await Task.sleep(nanoseconds: 500_000_000)
                await reloadDataAsync(customStartDate: initialFetchDate)
            } catch {
                await MainActor.run { self.errorMessage = "カロリーの保存に失敗: \(error.localizedDescription)" }
            }
        }
    }
    
    func addWeight(_ weight: Double, for date: Date) {
        Task {
            do {
                let saveDate = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
                try await healthKitManager.saveWeight(weight: weight, date: saveDate)
                try await Task.sleep(nanoseconds: 500_000_000)
                await reloadDataAsync(customStartDate: initialFetchDate)
            } catch {
                await MainActor.run { self.errorMessage = "体重の保存に失敗: \(error.localizedDescription)" }
            }
        }
    }
    
    func addSleep(start: Date, end: Date) {
        Task {
            do {
                try await healthKitManager.saveSleep(start: start, end: end)
                try await Task.sleep(nanoseconds: 500_000_000)
                await reloadDataAsync(customStartDate: initialFetchDate)
            } catch {
                await MainActor.run { self.errorMessage = "睡眠の保存に失敗: \(error.localizedDescription)" }
            }
        }
    }
    
    func deleteDietaryCalories(for date: Date) {
        Task {
            do {
                try await healthKitManager.deleteQuantityData(for: .dietaryEnergyConsumed, on: date)
                try await Task.sleep(nanoseconds: 500_000_000)
                await reloadDataAsync(customStartDate: initialFetchDate)
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
    
#if DEBUG
    // デバッグ用のデータ注入処理（自然なばらつきを再現）
    func injectDemoDataForScreenshots() {
        self.isDemoMode = true
        self.isLoading = true
        
        var demoData: [DailyMetrics] = []
        let calendar = Calendar.current
        let today = Date()
        
        // ベースとなる開始体重（ここから日々の収支によって変動させる）
        var currentWeight = 74.0
        
        for i in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // 1. 基礎代謝と運動カロリー（日によって運動量を変える）
            let resting = 1700.0 + Double.random(in: -20...20)
            let active = Double.random(in: 200...800)
            let totalBurned = resting + active
            
            // 2. 摂取カロリーの算出（約20%の確率でカロリーオーバーの日を作る）
            let isCheatDay = Double.random(in: 0...1) < 0.2
            let dietary: Double
            if isCheatDay {
                // 摂取超過（消費カロリー + 200〜800 kcal）
                dietary = totalBurned + Double.random(in: 200...800)
            } else {
                // 節制日（1400 〜 2100 kcal）
                dietary = Double.random(in: 1400...2100)
            }
            
            // 3. カロリー収支の計算と、それに基づく体重の変動（7200kcal = 1kg）
            let netCalories = dietary - totalBurned
            currentWeight += (netCalories / 7200.0)
            
            // グラフ上の見栄えを考慮し、日々の水分量ブレ等のノイズを付与
            let displayWeight = currentWeight + Double.random(in: -0.4...0.4)
            
            // 歩数はアクティブカロリーにある程度比例させる
            let baseSteps = Int(active * 15.0)
            let finalSteps = baseSteps + Int.random(in: -500...1500)
            
            let metrics = DailyMetrics(
                date: date,
                activeCalories: active,
                restingCalories: resting,
                dietaryCalories: dietary,
                steps: max(0, finalSteps),
                sleepSeconds: (6.5 + Double.random(in: -1.5...2.0)) * 3600.0,
                weight: displayWeight
            )
            demoData.append(metrics)
        }
        
        self.allData = demoData
        if let firstDate = demoData.first?.date {
            self.dietStartDate = firstDate
        }
        self.isLoading = false
    }
#endif
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

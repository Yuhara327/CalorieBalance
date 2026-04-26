//
//  HealthKitManager.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//
import HealthKit
import Foundation

enum HealthKitError: Error {
    case healthDataNotAvailable
    case typeInitializationFailed
    case queryFailed(Error)
}

class HealthKitManager {
    private let healthStore = HKHealthStore()
    
    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    func fetchDailyCalories(startDate: Date, endDate: Date) async throws -> [DailyMetrics] {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: endDate, options: [])
        
        async let activeDict = fetchStatisticsCollection(for: .activeEnergyBurned, unit: .kilocalorie(), options: .cumulativeSum, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        async let restingDict = fetchStatisticsCollection(for: .basalEnergyBurned, unit: .kilocalorie(), options: .cumulativeSum, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        async let dietaryDict = fetchStatisticsCollection(for: .dietaryEnergyConsumed, unit: .kilocalorie(), options: .cumulativeSum, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        async let stepDict = fetchStatisticsCollection(for: .stepCount, unit: .count(), options: .cumulativeSum, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        async let sleepDict = fetchSleepDuration(start: anchorDate, end: endDate)
        // 修正：体重取得時の単位を .gramUnit(with: .kilo) に変更（より確実な指定方法）
        async let massDict = fetchStatisticsCollection(for: .bodyMass, unit: HKUnit.gramUnit(with: .kilo), options: .mostRecent, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        
        let active = try await activeDict
        let resting = try await restingDict
        let dietary = try await dietaryDict
        let step = try await stepDict
        let sleep = try await sleepDict
        let mass = try await massDict
        
        var results: [DailyMetrics] = []
        var currentDate = anchorDate
        
        while currentDate <= endDate {
            let aCal = active[currentDate]
            let rCal = resting[currentDate]
            let dCal = dietary[currentDate]
            let stepCount = step[currentDate].flatMap { Int($0) }
            let sleepAnalysis = sleep[currentDate]
            let bodyMass = mass[currentDate]
            
            // 修正：最後の引数の後の不要なカンマを削除
            let data = DailyMetrics(
                date: currentDate,
                activeCalories: aCal,
                restingCalories: rCal,
                dietaryCalories: dCal,
                steps: stepCount,
                sleepSeconds: sleepAnalysis,
                weight: bodyMass
            )
            results.append(data)
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return results
    }
    
    private func fetchStatisticsCollection(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        predicate: NSPredicate,
        anchor: Date,
        interval: DateComponents,
        startDate: Date,
        endDate: Date
    ) async throws -> [Date: Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.typeInitializationFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options, anchorDate: anchor, intervalComponents: interval)
            
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                
                var dailySums: [Date: Double] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let quantity = (options == .cumulativeSum) ? statistics.sumQuantity() : statistics.mostRecentQuantity()
                    if let quantity = quantity {
                        dailySums[statistics.startDate] = quantity.doubleValue(for: unit)
                    }
                }
                
                continuation.resume(returning: dailySums)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepDuration(start: Date, end: Date) async throws -> [Date: Double] {
            let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            // 開始時間だけでなく、期間内に終了するデータも取得対象に含める
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            
            return try await withCheckedThrowingContinuation { con in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, err in
                    if let err = err {
                        con.resume(throwing: err)
                        return
                    }
                    
                    guard let categorySamples = samples as? [HKCategorySample] else {
                        con.resume(returning: [:])
                        return
                    }
                    
                    // 1. 覚醒や就寝中（InBed）などの不要なデータを除外し、実際の睡眠状態のみを抽出
                    let sleepSamples = categorySamples.filter { s in
                        s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                    
                    // 2. 起床日（endDate）を基準に、サンプルを日単位のグループに分類
                    var samplesByDay: [Date: [HKCategorySample]] = [:]
                    for s in sleepSamples {
                        let day = Calendar.current.startOfDay(for: s.endDate)
                        samplesByDay[day, default: []].append(s)
                    }
                    
                    var dict: [Date: Double] = [:]
                    
                    // 3. 各日ごとに重複する区間をマージし、純粋な睡眠時間を算出
                    for (day, daySamples) in samplesByDay {
                        // 開始時間で昇順ソート
                        let sortedSamples = daySamples.sorted { $0.startDate < $1.startDate }
                        var mergedIntervals: [(start: Date, end: Date)] = []
                        
                        for sample in sortedSamples {
                            if let last = mergedIntervals.last {
                                if sample.startDate <= last.end {
                                    // 区間が重複している場合、終了時間をより遅い方に拡張
                                    if sample.endDate > last.end {
                                        mergedIntervals[mergedIntervals.count - 1].end = sample.endDate
                                    }
                                } else {
                                    // 重複がない場合、独立した新しい区間として追加
                                    mergedIntervals.append((start: sample.startDate, end: sample.endDate))
                                }
                            } else {
                                // 最初の区間
                                mergedIntervals.append((start: sample.startDate, end: sample.endDate))
                            }
                        }
                        
                        // 結合された各区間の差分（秒数）の総和を計算
                        let totalSleepSeconds = mergedIntervals.reduce(0.0) { total, interval in
                            total + interval.end.timeIntervalSince(interval.start)
                        }
                        
                        dict[day] = totalSleepSeconds
                    }
                    
                    con.resume(returning: dict)
                }
                healthStore.execute(query)
            }
        }
    func saveWeight(weight: Double, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        // 修正：.kilogram() ではなく HKUnit.gramUnit(with: .kilo) を明示的に使用
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weight)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await healthStore.save(sample)
    }
    
    func saveDietaryEnergy(calories: Double, date: Date) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await healthStore.save(sample)
    }
    
    func saveSleep(start: Date, end: Date) async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: start,
            end: end
        )
        
        try await healthStore.save(sample)
    }
    
    func deleteSleepData(on date: Date) async throws {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        // 修正：.strictStartDate を削除して [] にする
        let datePredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, sourcePredicate])
        
        try await healthStore.deleteObjects(of: type, predicate: predicate)
    }
    
    // 念のためこちらも同様に修正
    func deleteQuantityData(for identifier: HKQuantityTypeIdentifier, on date: Date) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        // 修正：.strictStartDate を削除して [] にする
        let datePredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, sourcePredicate])
        
        try await healthStore.deleteObjects(of: type, predicate: predicate)
    }
    // MARK: - 個別カロリー記録の管理
        
        /// 指定された日のすべてのカロリー記録を取得し、CalorieRecordの配列として返します
        func fetchDailyCalorieRecords(for date: Date) async throws -> [CalorieRecord] {
            guard let calorieType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                throw HealthKitError.typeInitializationFailed
            }
            
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: date)
            guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
                // 既存のエラー列挙型に適合させるため、NSErrorをラップするか独自のエラーを投げます
                throw HealthKitError.healthDataNotAvailable
            }
            
            // strictStartDateを使用せず、既存の実装に合わせたpredicate
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: calorieType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    
                    if let error = error {
                        continuation.resume(throwing: HealthKitError.queryFailed(error))
                        return
                    }
                    
                    guard let quantitySamples = samples as? [HKQuantitySample] else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let records = quantitySamples.map { sample -> CalorieRecord in
                        let calories = sample.quantity.doubleValue(for: .kilocalorie())
                        let isOwnApp = sample.sourceRevision.source == HKSource.default()
                        
                        return CalorieRecord(
                            id: UUID(),
                            sample: sample,
                            calories: calories,
                            date: sample.startDate,
                            isOwnApp: isOwnApp
                        )
                    }
                    
                    continuation.resume(returning: records)
                }
                
                healthStore.execute(query)
            }
        }
        
        /// 指定されたカロリー記録（HKQuantitySample）を削除します
        func deleteCalorieRecord(_ record: CalorieRecord) async throws {
            return try await withCheckedThrowingContinuation { continuation in
                healthStore.delete(record.sample) { success, error in
                    if let error = error {
                        continuation.resume(throwing: HealthKitError.queryFailed(error))
                    } else if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: HealthKitError.healthDataNotAvailable)
                    }
                }
            }
        }
}

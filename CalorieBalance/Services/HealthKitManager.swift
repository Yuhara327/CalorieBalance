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
        let typesToShare: Set<HKSampleType> = []
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    func fetchDailyCalories(startDate: Date, endDate: Date) async throws -> [DailyMetrics] {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: anchorDate, end: endDate, options: .strictStartDate)
        
        async let activeDict = fetchStatisticsCollection(for: .activeEnergyBurned, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        async let restingDict = fetchStatisticsCollection(for: .basalEnergyBurned, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        async let dietaryDict = fetchStatisticsCollection(for: .dietaryEnergyConsumed, predicate: predicate, anchor: anchorDate, interval: interval, startDate: anchorDate, endDate: endDate)
        
        let active = try await activeDict
        let resting = try await restingDict
        let dietary = try await dietaryDict
        
        var results: [DailyMetrics] = []
        var currentDate = anchorDate
        
        while currentDate <= endDate {
            let aCal = active[currentDate] ?? nil
            let rCal = resting[currentDate] ?? nil
            let dCal = dietary[currentDate] ?? nil
            
            let data = DailyMetrics(
                date: currentDate,
                activeCalories: aCal,
                restingCalories: rCal,
                dietaryCalories: dCal
            )
            results.append(data)
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return results
    }
    
    private func fetchStatisticsCollection(for identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, anchor: Date, interval: DateComponents, startDate: Date, endDate: Date) async throws -> [Date: Double?] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.typeInitializationFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: anchor, intervalComponents: interval)
            
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                
                var dailySums: [Date: Double?] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    // statistics.sumQuantity() が nil なら、その期間のデータは存在しない
                    if let sum = statistics.sumQuantity() {
                        dailySums[statistics.startDate] = sum.doubleValue(for: .kilocalorie())
                    } else {
                        dailySums[statistics.startDate] = nil // 明示的にnilを代入
                    }
                }
                
                continuation.resume(returning: dailySums)
            }
            
            healthStore.execute(query)
        }
    }
}

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
    
    func requestAuthorization() {
        let typesToShare: Set<HKSampleType> = []
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead){ (success, error) in
            if let error = error {
                print("HealthKit authorization failed with error: \(error)")
            }
        }
    }
    
    //fetchStatisticsCollectionから辞書型を持ってきて、まとめてCalorieDataクラスの形にして返す。
    func fetchDailyCalories(startDate: Date, endDate: Date) async throws -> [CalorieData] {
        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        async let activeDict = fetchStatisticsCollection(for: .activeEnergyBurned, predicate: predicate, anchor: anchorDate, interval: interval, startDate: startDate, endDate: endDate)
        async let restingDict = fetchStatisticsCollection(for: .basalEnergyBurned, predicate: predicate, anchor: anchorDate, interval: interval, startDate: startDate, endDate: endDate)
        async let dietaryDict = fetchStatisticsCollection(for: .dietaryEnergyConsumed, predicate: predicate, anchor: anchorDate, interval: interval, startDate: startDate, endDate: endDate)
        
        let active = try await activeDict
        let resting = try await restingDict
        let dietary = try await dietaryDict
        
        var results: [CalorieData] = []
        var currentDate = anchorDate
        
        while currentDate <= endDate {
            let aCal = active[currentDate] ?? 0.0
            let rCal = resting[currentDate] ?? 0.0
            let dCal = dietary[currentDate] ?? 0.0
            
            let data = CalorieData(
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
    
    //heatlhkitから日次データを取得する関数。何を取ってくるかを渡して、辞書で返す
    private func fetchStatisticsCollection(for identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, anchor: Date, interval: DateComponents, startDate: Date, endDate: Date) async throws -> [Date: Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.typeInitializationFailed
        }
        
        return try await withCheckedThrowingContinuation{ continuation in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: anchor, intervalComponents: interval)
            
            query.initialResultsHandler = {_, collection, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                var dailySums: [Date: Double] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let sum = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
                    dailySums[statistics.startDate] = sum
                }
                
                continuation.resume(returning: dailySums)
            }
            
            healthStore.execute(query)
        }
    }
}

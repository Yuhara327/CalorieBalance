//
//  CalorieRecord.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/04/25.
//

import Foundation
import HealthKit

struct CalorieRecord: Identifiable {
    let id: UUID
    let sample: HKQuantitySample
    let calories: Double
    let date: Date
    let isOwnApp: Bool
}

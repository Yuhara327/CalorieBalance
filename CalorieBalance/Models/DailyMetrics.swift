//
//  CalorieData.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

import Foundation
import SwiftUI

struct DailyMetrics: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let activeCalories: Double?
    let restingCalories: Double?
    let dietaryCalories: Double?
    let steps: Int?
    let sleepSeconds: Double?
    let weight: Double?
    
    var totalBurnedCalories: Double? {
        guard let active = activeCalories, let resting = restingCalories else { return nil }
        return active + resting
    }
    
    var netCalories: Double? {
        guard let dietary = dietaryCalories, let totalBurned = totalBurnedCalories else { return nil }
        return dietary - totalBurned
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DailyMetrics, rhs: DailyMetrics) -> Bool {
        lhs.id == rhs.id
    }
}

extension DailyMetrics {
    var netColor: Color {
        guard let net = netCalories else { return .secondary }
        return net <= 0 ? .green : .red
    }
}

extension DailyMetrics {
    // 脂肪換算の計算（1000g = 7200kcal）
    var fatEquivalentGram: Double {
        abs((netCalories ?? 0) / 7.2)
    }
}

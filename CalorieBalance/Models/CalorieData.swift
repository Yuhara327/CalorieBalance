//
//  CalorieData.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

import Foundation

struct CalorieData: Identifiable {
    let id = UUID()
    let date: Date
    let activeCalories: Double
    let restingCalories: Double
    let dietaryCalories: Double
    var totalBurnedCalories: Double {
        return activeCalories + restingCalories
    }
    var netCalories: Double{
        return dietaryCalories - totalBurnedCalories
    }
}

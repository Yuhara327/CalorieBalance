//
//  WeightChartData.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/18.
//

import Foundation

struct WeightChartData: Identifiable {
    let id = UUID()
    let date: Date
    let actualWeight: Double?
    let predictedWeight: Double?
}

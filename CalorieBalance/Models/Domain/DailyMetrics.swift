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



// コーディング用
extension DailyMetrics {
    // プレビュー用のダミーデータ（過去30日分）
    static var mockData: [DailyMetrics] {
        var mocks: [DailyMetrics] = []
        let calendar = Calendar.current
        let today = Date()
        
        // 基準となる体重（例えば65.0kgからスタート）
        var currentWeight = 65.0
        
        for i in (0..<30).reversed() { // 30日前から今日に向かって生成
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            
            // ランダムな摂取・消費カロリーを生成
            let dietary = Double.random(in: 1800...2500)
            let burned = Double.random(in: 2000...2800)
            
            // 理論値としての体重推移
            let net = dietary - burned
            currentWeight += (net / 7200.0)
            
            // ---- ここから追加・修正 ----
            
            // ① 現実のブレ（ノイズ）：±400g程度の水分の増減をシミュレート
            let dailyNoise = Double.random(in: -0.4...0.4)
            
            // ② 測り忘れ（nil）：20%の確率で体重を量り忘れたことにする
            let isWeightRecorded = Double.random(in: 0...1) > 0.2
            let recordedWeight = isWeightRecorded ? (currentWeight + dailyNoise) : nil
            
            // ------------------------
            
            let mock = DailyMetrics(
                date: date,
                activeCalories: burned * 0.3,
                restingCalories: burned * 0.7,
                dietaryCalories: dietary,
                steps: Int.random(in: 3000...12000),
                sleepSeconds: Double.random(in: 20000...30000),
                weight: recordedWeight // ノイズとnilを含んだリアルな体重を渡す
            )
            mocks.append(mock)
        }
        return mocks
    }
}

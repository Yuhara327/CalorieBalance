//
//  DailyCalorieRow.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/17.
//

// Daily画面の一列
import SwiftUI

// 日次のリスト
struct DailyCalorieRow: View {
    let data: DailyMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(formatDate(data.date))
                .font(.headline)
            
            HStack {
                // 消費カロリー
                VStack(alignment: .leading) {
                    Text("消費カロリー").font(.caption).foregroundColor(.secondary)
                    if let burned = data.totalBurnedCalories {
                        // 数値と単位を分離（Interpolationを使用）
                        Text("\(Int(burned)) kcal")
                            .font(.subheadline).bold()
                    } else {
                        Text("-- kcal").font(.subheadline).bold()
                    }
                }
                
                Spacer()
                
                // 収支
                VStack(alignment: .center) {
                    Text("収支").font(.caption).foregroundColor(.secondary)
                    Group {
                        if let netCalories = data.netCalories {
                            Text("\(Int(netCalories)) kcal")
                        } else {
                            Text("-- kcal")
                        }
                    }
                    .font(.title).bold()
                    .foregroundColor(data.netColor)
                }
                
                Spacer()
                
                // 摂取カロリー
                VStack(alignment: .trailing) {
                    Text("摂取カロリー").font(.caption).foregroundColor(.secondary)
                    if let dietary = data.dietaryCalories {
                        // 数値と単位を分離
                        Text("\(Int(dietary)) kcal")
                            .font(.subheadline).bold()
                    } else {
                        Text("-- kcal").font(.subheadline).bold()
                    }
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    private func formatDate(_ date: Date) -> String {
        return date.formatted(.dateTime.year().month().day())
    }
}

#Preview {
    // プレビュー用のダミーデータを作成
    let sampleData = DailyMetrics(
        date: Date(),
        activeCalories: 600,
        restingCalories: 1500,
        dietaryCalories: 1800,
        steps: 10000,
        sleepSeconds: 25200,
        weight: 65.0
    )
    
    // 生成したデータを引数 data に渡す
    return DailyCalorieRow(data: sampleData)
        .padding() // プレビューで見やすくするための余白
}

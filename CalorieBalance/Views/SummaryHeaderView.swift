//
//  SummaryHeaderView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/17.
//

import SwiftUI

struct SummaryHeaderView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    
    private var totalFatEquivalent: Double {
        abs(viewModel.totalNetCalories / 7200.0)
    }
    
    var showMonthPicker: Bool = true
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                // 修正：多言語化
                Text(String(localized: "開始日"))
                    .font(.subheadline).foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: $viewModel.dietStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: viewModel.dietStartDate) {
                        viewModel.requestAccessAndFetchData()
                    }
            }
            .padding(.horizontal)
            
            VStack(spacing: 5) {
                // 修正：数値と単位 kcal の分離
                Text("\(Int(viewModel.totalNetCalories)) kcal")
                    .font(.title).bold()
                    .foregroundColor(viewModel.totalNetCalories <= 0 ? .green : .red)
                
                // 修正：Measurement API を使用して kg を自動変換（lb対応）
                let fatMeasurement = Measurement(value: abs(totalFatEquivalent), unit: UnitMass.kilograms)
                Text("脂肪換算で約 \(fatMeasurement.formatted(.measurement(width: .abbreviated, usage: .personWeight)))")
                    .font(.footnote).foregroundColor(.secondary)
            }
            
            if showMonthPicker {
                HStack {
                    Button(action: { viewModel.changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left.circle.fill").font(.title2).foregroundColor(.teal)
                    }
                    Spacer()
                    
                    // 修正：月表示をシステム設定に合わせる
                    Text(viewModel.selectedMonth.formatted(.dateTime.year().month()))
                        .font(.headline)
                    
                    Spacer()
                    Button(action: { viewModel.changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundColor(.teal)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    SummaryHeaderView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

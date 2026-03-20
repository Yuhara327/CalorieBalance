//
//  SummaryHeaderView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/17.
//

// ヘッダー部分

import SwiftUI

struct SummaryHeaderView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    private var totalFatEquivalent: Double {
            abs(viewModel.totalNetCalories / 7200.0)
        }
    var showMonthPicker: Bool  = true
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("開始日").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: $viewModel.dietStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: viewModel.dietStartDate) { viewModel.requestAccessAndFetchData() }
            }
            .padding(.horizontal)
            
            VStack(spacing: 5) {
                // totalNetCalories は ViewModel 側で compactMap 済みなので Double
                Text("\(Int(viewModel.totalNetCalories)) kcal")
                    .font(.title).bold()
                    .foregroundColor(viewModel.totalNetCalories <= 0 ? .green : .red)
                
                Text(String(format: "脂肪換算で約 %.2f kg", abs(totalFatEquivalent)))
                    .font(.footnote).foregroundColor(.secondary)
            }
            if showMonthPicker {
                HStack {
                    Button(action: { viewModel.changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left.circle.fill").font(.title2).foregroundColor(.teal)
                    }
                    Spacer()
                    Text(formatMonth(viewModel.selectedMonth)).font(.headline)
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
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: date)
    }
}

#Preview {
    SummaryHeaderView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

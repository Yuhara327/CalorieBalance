//
//  SummaryHeaderView.swift
//  CalorieBalance
//

import SwiftUI

struct SummaryHeaderView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    
    private var totalFatEquivalent: Double {
        abs(viewModel.graphTotalNetCalories / 7200.0)
    }
    
    var showMonthPicker: Bool = true
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(String(localized: "表示開始日"))
                    .font(.subheadline).foregroundColor(.secondary)
                Spacer()
                
                DatePicker("", selection: $viewModel.graphDisplayStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: viewModel.graphDisplayStartDate) {
                        viewModel.requestAccessAndFetchData()
                    }
            }
            .padding(.horizontal)
            
            VStack(spacing: 5) {
                Text("\(Int(viewModel.graphTotalNetCalories)) kcal")
                    .font(.title).bold()
                    .foregroundColor(viewModel.graphTotalNetCalories <= 0 ? .green : .red)
                
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

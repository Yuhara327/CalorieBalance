//
//  ContentView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalorieBalanceViewModel()
    
    var body: some View {
        NavigationStack{
            ZStack {
                if viewModel.isLoading{
                    ProgressView("データを取得中")
                }
                else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage)
                            .foregroundColor(.red)
                        Button("再試行") {
                            viewModel.requestAccessAndFetchData()
                        }
                        .padding()
                    }
                }
                else {
                    VStack(spacing: 0) {
                        SummaryHeaderView(viewModel: viewModel)
                        
                        Divider()
                        
                        List {
                            if viewModel.filteredData.isEmpty {
                                ContentUnavailableView("データがありません", systemImage: "calendar.badge.exclamationmark", description: Text("この期間の記録はヘルスケアアプリに見つかりませんでした。"))
                            } else {
                                ForEach(viewModel.filteredData) { data in
                                    DailyCalorieRow(data: data)
                                }
                            }
                        }
                        .listStyle(.insetGrouped) // iOS標準らしい見た目になります}
                    }
                }
            }
            .navigationTitle("Daily")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task {
                viewModel.requestAccessAndFetchData()
            }
            .refreshable {
                viewModel.requestAccessAndFetchData()
            }
        }
    }
}

//日次のリスト
struct DailyCalorieRow: View {
    let data: DailyMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(formatDate(data.date))
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("消費カロリー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(data.totalBurnedCalories)) kcal")
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("収支")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(data.netCalories))")
                        .font(.title)
                        .foregroundColor(data.netCalories <= 0 ? .green : .red)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("摂取カロリー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(data.dietaryCalories))kcal")
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct SummaryHeaderView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    
    private var kg: Double {
        viewModel.totalNetCalories / 7200.0
    }
    
    var body: some View {
        VStack(spacing: 10) {
            
            HStack{
                Text("開始日")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: $viewModel.dietStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: viewModel.dietStartDate) {
                        viewModel.requestAccessAndFetchData()
                    }
            }
            .padding(.horizontal)
            VStack(spacing: 5) {
                Text("\(Int(viewModel.totalNetCalories)) kcal")
                    .font(.title)
                    .foregroundColor(viewModel.totalNetCalories <= 0 ? .green : .red)
                    .bold()
                Text(String(format: "脂肪換算で約 %.2f kg", abs(kg)))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            HStack {
                Button(action: { viewModel.changeMonth(by: -1)}) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                }
                Spacer()
                Text(formatMonth(viewModel.selectedMonth))
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.changeMonth(by: 1)}) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.headline)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
    }
        private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}

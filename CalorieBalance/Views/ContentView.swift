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
        NavigationView {
            ZStack {
                if viewModel.isLoading{
                    ProgressView("データを取得中")
                }
                else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                else {
                    List {
                        // セクションのヘッダーとして配置するか、単純に最初の行として置く
                        Section {
                            ForEach(viewModel.dailyData, id: \.date) { data in
                                DailyCalorieRow(data: data)
                            }
                        } header: {
                            // ここに置くと、リストと一緒にスクロールされます
                            SummaryHeaderView(data: viewModel.dailyData)
                                .listRowInsets(EdgeInsets()) // 余計な空白を消す
                        }
                    }
                    .listStyle(InsetGroupedListStyle()) // iOS標準らしい見た目になります}
                }
            }
            .navigationTitle("カロリーバランス")
            
            .task {
                viewModel.requestAccessAndFetchData()
            }
        }
    }
}

//日次のリスト
struct DailyCalorieRow: View {
    let data: CalorieData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.vertical)
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
    let data: [CalorieData]
    
    private var totalNet: Double {
        data.reduce(0) { $0 + $1.netCalories }
    }
    
    private var kg: Double {
        totalNet / 7200.0
    }
    
    var body: some View {
        VStack(spacing:8) {
            Text("期間内の収支")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Int(totalNet)) kcal")
                .font(.title)
                .foregroundColor(totalNet <= 0 ? .green : .red)
                .bold()
            Text(String(format: "脂肪換算で約 %.2f kg %@", abs(kg)))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContentView()
}

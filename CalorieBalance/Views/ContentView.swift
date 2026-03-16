//
//  ContentView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalorieBalanceViewModel()
    let backGroundColor = LinearGradient(gradient: Gradient(colors: [Color.teal, Color.white]), startPoint: .top, endPoint: .bottom)

    var body: some View {
        NavigationStack {
            ZStack {
                AdvancedBackgroundView()
                if viewModel.isLoading {
                    ProgressView("データを取得中")
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage).foregroundColor(.red)
                        Button("再試行") { viewModel.requestAccessAndFetchData() }.padding()
                    }
                } else {
                    VStack(spacing: 0) {
                        SummaryHeaderView(viewModel: viewModel)
                            .glassEffect(in: .rect(cornerRadius: 30.0))
                            .padding()
                        List {
                            if viewModel.filteredData.isEmpty {
                                ContentUnavailableView("データがありません", systemImage: "calendar.badge.exclamationmark", description: Text("この期間の記録はヘルスケアアプリに見つかりませんでした。"))
                            } else {
                                ForEach(viewModel.filteredData) { data in
                                    NavigationLink(value: data) {
                                        DailyCalorieRow(data: data)
                                    }
                                    .listRowBackground(Color.clear)
                                    .padding(4)
                                }
                                Color.clear
                                    .frame(height: 100) // 100pt分の空白
                                    .listRowBackground(Color.clear) // 背景を透明に
                                    .listRowSeparator(.hidden)      // 境界線を消す
                            }
                        }
                        .glassEffect(in: .rect(
                                topLeadingRadius: 30,
                                bottomLeadingRadius: 0, // 下側は角を丸めない
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 30,
                                style: .continuous
                            ))
                        .padding([.horizontal, .top]) // 横と上だけ余白を作り、下（.bottom）は空けない
                        .ignoresSafeArea(edges: .bottom)
                        .navigationDestination(for: DailyMetrics.self) { data in
                            DayDetailView(metrics: data)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Daily")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task { viewModel.requestAccessAndFetchData() }
            .refreshable { viewModel.requestAccessAndFetchData() }
        }
    }
}

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
                    // totalBurnedCalories が nil なら "--"
                    Text(data.totalBurnedCalories != nil ? "\(Int(data.totalBurnedCalories!)) kcal" : "-- kcal")
                        .font(.subheadline).bold()
                }
                
                Spacer()
                
                // 収支
                VStack(alignment: .center) {
                    Text("収支").font(.caption).foregroundColor(.secondary)
                    // netCalories が nil なら "--"
                    Text(data.netCalories != nil ? "\(Int(data.netCalories!))" : "--")
                        .font(.title).bold()
                        .foregroundColor(data.netColor)
                }
                
                Spacer()
                
                // 摂取カロリー
                VStack(alignment: .trailing) {
                    Text("摂取カロリー").font(.caption).foregroundColor(.secondary)
                    Text(data.dietaryCalories != nil ? "\(Int(data.dietaryCalories!))kcal" : "-- kcal")
                        .font(.subheadline).bold()
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
                
                Text(String(format: "脂肪換算で約 %.2f kg", abs(kg)))
                    .font(.footnote).foregroundColor(.secondary)
            }
            
            HStack {
                Button(action: { viewModel.changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left.circle.fill").font(.title2)
                }
                Spacer()
                Text(formatMonth(viewModel.selectedMonth)).font(.headline)
                Spacer()
                Button(action: { viewModel.changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right.circle.fill").font(.title2)
                }
            }
            .padding(.horizontal)
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
    ContentView()
}

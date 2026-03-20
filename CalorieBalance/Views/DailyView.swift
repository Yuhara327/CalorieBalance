//
//  ContentView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

//Daily画面

import SwiftUI

struct DailyView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel

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
                                    .frame(height: 80) // 100pt分の空白
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
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationDestination(for: DailyMetrics.self) { data in
                DayDetailView(metrics: data)
            }
            .navigationTitle("Daily")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable { viewModel.requestAccessAndFetchData() }
        }
    }
}
#Preview {
    DailyView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

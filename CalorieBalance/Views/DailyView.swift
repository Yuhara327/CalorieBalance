//
//  DailyView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

import SwiftUI

struct DailyView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AdvancedBackgroundView()
                
                if viewModel.isLoading {
                    ProgressView(String(localized: "データを取得中"))
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage).foregroundColor(.red)
                        Button(String(localized: "再試行")) {
                            viewModel.requestAccessAndFetchData()
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 0) {
                        SummaryHeaderView(viewModel: viewModel)
                            .glassEffect(in: .rect(cornerRadius: 30.0))
                            .padding()
                        
                        dailyList
                    }
                }
            }
            .navigationDestination(for: DailyMetrics.self) { data in
                DayDetailView(viewModel: viewModel, metrics: data)
            }
            .navigationTitle("Daily")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: URL(string: "https://yuhara327.github.io/CalorieBalance/")!) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .task {
                await viewModel.refreshData()
            }
        }
    }

    private var dailyList: some View {
        List {
            if viewModel.filteredData.isEmpty {
                ContentUnavailableView(
                    String(localized: "データがありません"),
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("この期間の記録はヘルスケアアプリに見つかりませんでした。")
                )
            } else {
                // 日付で降順（新しい順）にソートして表示
                ForEach(viewModel.filteredData.sorted(by: { $0.date > $1.date })) { data in
                    NavigationLink(value: data) {
                        DailyCalorieRow(data: data)
                    }
                    .listRowBackground(Color.clear)
                    .padding(4)
                }
                
                Color.clear
                    .frame(height: 80)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .glassEffect(in: .rect(
            topLeadingRadius: 30,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 30,
            style: .continuous
        ))
        .padding([.horizontal, .top])
        .ignoresSafeArea(edges: .bottom)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    DailyView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
        .environment(\.locale, .init(identifier: "fr"))
}

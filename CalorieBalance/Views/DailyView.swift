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
                    // 修正：多言語化対応
                    ProgressView(String(localized: "データを取得中"))
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage).foregroundColor(.red)
                        // 修正：多環境対応
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
                        
                        List {
                            if viewModel.filteredData.isEmpty {
                                // 修正：ContentUnavailableView 内のテキストを多言語化
                                ContentUnavailableView(
                                    String(localized: "データがありません"),
                                    systemImage: "calendar.badge.exclamationmark",
                                    description: Text("この期間の記録はヘルスケアアプリに見つかりませんでした。")
                                )
                            } else {
                                ForEach(viewModel.filteredData) { data in
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
            }
            .navigationDestination(for: DailyMetrics.self) { data in
                DayDetailView(viewModel: viewModel, metrics: data)
            }
            .navigationTitle("Daily")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable {
                await viewModel.refreshData()
            }
        }
    }
}

#Preview {
    DailyView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

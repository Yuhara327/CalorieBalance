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
                // 背景
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
                        
                        List {
                            if viewModel.filteredData.isEmpty {
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
                
                // MARK: - デバッグ用の透明ボタン（最前面レイヤー）
                #if DEBUG
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            viewModel.injectDemoDataForScreenshots()
                        }) {
                            // 完全に透明だが、タップ判定は残る（幅80x高さ44の標準的なボタンサイズ）
                            Color.black.opacity(0.001)
                                .frame(width: 80, height: 44)
                        }
                    }
                    Spacer()
                }
                // ナビゲーションバーの下に被らないように調整
                .padding(.top, 10)
                .padding(.trailing, 10)
                #endif
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
        .environment(\.locale, .init(identifier: "fr"))
}

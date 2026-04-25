//
//  GraphView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/18.
//

import SwiftUI
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    @StateObject private var subManager = SubscriptionManager.shared
    
    // 全グラフ共通の開始日
    @State private var graphStartDate: Date
    @State private var selectedDate: Date? = nil
    
    init(viewModel: CalorieBalanceViewModel) {
        self.viewModel = viewModel
        
        // 共有の UserDefaults からダイエット開始日を取得
        let sharedDefaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance")
        let interval = sharedDefaults?.double(forKey: "dietStartDate") ?? 0
        
        let initialDate: Date
        if interval == 0 {
            // 設定がない場合は30日前をデフォルトに
            initialDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        } else {
            initialDate = Date(timeIntervalSince1970: interval)
        }
        
        _graphStartDate = State(initialValue: initialDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdvancedBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // --- サマリーヘッダー ---
                        // デザインの一致のためカード形式でラップ
                        VStack(spacing: 0) {
                            SummaryHeaderView(viewModel: viewModel, showMonthPicker: false)
                        }
                        .glassEffect(in: .rect(cornerRadius: 30.0))
                        // ヘッダー内のDatePickerがviewModel.graphDisplayStartDateを変更した際の同期
                        .onChange(of: viewModel.graphDisplayStartDate) { _, newValue in
                            if self.graphStartDate != newValue {
                                self.graphStartDate = newValue
                            }
                        }
                        
                        // 1. カロリー収支グラフ 【無料】
                        ChartCard(title: String(localized: "カロリー収支"), startDate: $graphStartDate) { newValue in
                            // カード側で日付が変わった場合、ViewModelへ反映しデータを再取得
                            viewModel.graphDisplayStartDate = newValue
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            CalorieTrendChart(
                                viewModel: viewModel,
                                graphStartDate: graphStartDate,
                                selectedDate: $selectedDate
                            )
                        }
                        
                        // 2. 体重グラフ 【有料(Pro)】
                        ChartCard(title: String(localized: "体重"), startDate: $graphStartDate) { newValue in
                            viewModel.graphDisplayStartDate = newValue
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            ZStack {
                                WeightTrendChart(
                                    viewModel: viewModel,
                                    graphStartDate: graphStartDate,
                                    selectedDate: $selectedDate
                                )
                                .blur(radius: subManager.isPremium ? 0 : 6)
                                
                                if !subManager.isPremium {
                                    ProFeatureOverlay(
                                        title: String(localized: "体重予測の解放"),
                                        message: String(localized: "日々のカロリーから未来の体重を予測し、モチベーションを維持しましょう。\n無料期間で機能を試せます。")
                                    )
                                }
                            }
                        }
                        
                        // 3. 睡眠グラフ 【有料(Pro)】
                        ChartCard(title: String(localized: "睡眠と日次カロリー収支"), startDate: $graphStartDate) { newValue in
                            viewModel.graphDisplayStartDate = newValue
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            ZStack {
                                SleepTrendChart(
                                    viewModel: viewModel,
                                    graphStartDate: graphStartDate,
                                    selectedDate: $selectedDate
                                )
                                .blur(radius: subManager.isPremium ? 0 : 6)
                                
                                if !subManager.isPremium {
                                    ProFeatureOverlay(
                                        title: String(localized: "睡眠相関の解放"),
                                        message: String(localized: "睡眠不足がダイエットに与える影響を分析し、最適な生活リズムを見つけましょう。\n無料期間で機能を試せます。")
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle(String(localized: "Trend"))
                .toolbarTitleDisplayMode(.inlineLarge)
                .refreshable {
                    await viewModel.refreshData()
                }
                .task {
                    // 開始日が変更されている可能性を考慮してデータ取得
                    await viewModel.refreshData()
                }
            }
        }
    }
}

#Preview {
    GraphView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

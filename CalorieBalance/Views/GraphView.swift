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
    // 追加: 課金マネージャーを監視
    @StateObject private var subManager = SubscriptionManager.shared
    
    @AppStorage("dietStartDate") private var dietStartDate: Date?
    
    // 全グラフ共通の開始日
    @State private var graphStartDate: Date
    @State private var selectedDate: Date? = nil
    
    init(viewModel: CalorieBalanceViewModel) {
        self.viewModel = viewModel
        
        // 修正：共有の UserDefaults (SuiteName) から取得するように安全策を講じる
        let sharedDefaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance")
        let interval = sharedDefaults?.double(forKey: "dietStartDate") ?? 0
        
        let initialDate: Date
        if interval == 0 {
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // サマリーヘッダー（月選択は非表示）
                        SummaryHeaderView(viewModel: viewModel, showMonthPicker: false)
                            .glassEffect(in: .rect(cornerRadius: 30.0))
                        
                        // 1. カロリー収支グラフ 【無料】 - 一番上に移動
                        ChartCard(title: String(localized: "カロリー収支"), startDate: $graphStartDate) { newValue in
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
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            ZStack {
                                WeightTrendChart(
                                    viewModel: viewModel,
                                    graphStartDate: graphStartDate,
                                    selectedDate: $selectedDate
                                )
                                // 未課金時はグラフをぼかして(opacity等で調整も可)オーバーレイを表示
                                .blur(radius: subManager.isPremium ? 0 : 6)
                                
                                if !subManager.isPremium {
                                    ProFeatureOverlay(
                                        title: String(localized: "体重予測の解放"),
                                        message: String(localized: "日々のカロリーから未来の体重を予測し、モチベーションを維持しましょう。")
                                    )
                                }
                            }
                        }
                        
                        // 3. 睡眠グラフ 【有料(Pro)】
                        ChartCard(title: String(localized: "睡眠と日次カロリー収支"), startDate: $graphStartDate) { newValue in
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
                                        message: String(localized: "睡眠不足がダイエットに与える影響を分析し、最適な生活リズムを見つけましょう。")
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
            }
        }
    }
}

#Preview {
    GraphView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

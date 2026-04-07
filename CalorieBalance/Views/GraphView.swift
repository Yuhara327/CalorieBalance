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
    @AppStorage("dietStartDate") private var dietStartDate: Date?
    
    // 全グラフ共通の開始日
    @State private var graphStartDate: Date
    
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
    
    @State private var selectedDate: Date? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdvancedBackgroundView()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // サマリーヘッダー（月選択は非表示）
                        SummaryHeaderView(viewModel: viewModel, showMonthPicker: false)
                            .glassEffect(in: .rect(cornerRadius: 30.0))
                        
                        // 体重グラフ
                        // 修正：タイトルを多言語化
                        ChartCard(title: String(localized: "体重"), startDate: $graphStartDate) { newValue in
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            WeightTrendChart(
                                viewModel: viewModel,
                                graphStartDate: graphStartDate,
                                selectedDate: $selectedDate
                            )
                        }
                        
                        // カロリー収支グラフ
                        // 修正：タイトルを多言語化
                        ChartCard(title: String(localized: "カロリー収支"), startDate: $graphStartDate) { newValue in
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            CalorieTrendChart(
                                viewModel: viewModel,
                                graphStartDate: graphStartDate,
                                selectedDate: $selectedDate
                            )
                        }
                        
                        // 睡眠グラフ
                        // 修正：タイトルを多言語化
                        ChartCard(title: String(localized: "睡眠と日次カロリー収支"), startDate: $graphStartDate) { newValue in
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            SleepTrendChart(
                                viewModel: viewModel,
                                graphStartDate: graphStartDate,
                                selectedDate: $selectedDate
                            )
                        }
                    }
                    .padding()
                }
                // 修正：ナビゲーションタイトルを多言語化
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

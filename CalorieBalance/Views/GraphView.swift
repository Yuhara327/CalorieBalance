//
//  GraphView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/18.
//

// GraphView.swift
import SwiftUI
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    // 全グラフ共通の開始日。これを各ChartCardに渡すことで一括連動を実現します。
    @State private var graphStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var selectedDate: Date? = nil//グラフタップでデータ出すやつの日付を保持
    
    var body: some View {
        NavigationStack{
            ZStack{
                AdvancedBackgroundView()
                ScrollView {
                    VStack(spacing: 24) {
                        // サマリーヘッダー
                        SummaryHeaderView(viewModel: viewModel, showMonthPicker: false)
                            .glassEffect(in: .rect(cornerRadius: 30.0))
                        
                        // 体重グラフ
                        // すべてのChartCardに $graphStartDate を渡せば、どれかを変えると全部変わります
                        ChartCard(title: "体重", startDate: $graphStartDate) { newValue in
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            WeightTrendChart(
                                viewModel: viewModel,
                                graphStartDate: graphStartDate,
                                selectedDate: $selectedDate
                            )
                        }
                        
                        /* 2個目のグラフを追加する場合も同じ $graphStartDate を使う */
                        /*
                         ChartCard(title: "カロリー収支", startDate: $graphStartDate) { newValue in
                         viewModel.requestAccessAndFetchData(customStartDate: newValue)
                         } content: {
                         CalorieTrendChart(viewModel: viewModel, graphStartDate: graphStartDate)
                         }
                         */
                    }
                    .padding()
                }
                .navigationTitle("Trend")
                .toolbarTitleDisplayMode(.inlineLarge)
                .refreshable { viewModel.requestAccessAndFetchData() }
            }
        }
    }
}

// 構造体の外に配置
#Preview {
    GraphView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

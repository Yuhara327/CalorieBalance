//
//  GraphView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/18.
//

// GraphView.swift

// グラフ画面統括
import SwiftUI
import Charts

struct GraphView: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    @AppStorage("dietStartDate") private var dietStartDate: Date?
    // 全グラフ共通の開始日。これを各ChartCardに渡すことで一括連動を実現します。
    @State private var graphStartDate: Date
    init(viewModel: CalorieBalanceViewModel) {
        self.viewModel = viewModel
        
        // UserDefaultsからTimeIntervalとして取得
        let interval = UserDefaults.standard.double(forKey: "dietStartDate")
        
        // 値が0（未保存）の場合はデフォルト（29日前）を生成、ある場合はその値からDateを作成
        let initialDate: Date
        if interval == 0 {
            initialDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        } else {
            initialDate = Date(timeIntervalSince1970: interval)
        }
        
        _graphStartDate = State(initialValue: initialDate)
    }
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
                        
                        ChartCard(title: "カロリー収支", startDate: $graphStartDate) { newValue in
                            viewModel.requestAccessAndFetchData(customStartDate: newValue)
                        } content: {
                            CalorieTrendChart(
                                viewModel: viewModel,
                                graphStartDate: graphStartDate,
                                selectedDate: $selectedDate
                            )
                        }
                        
                        ChartCard(title: "睡眠と日次カロリー収支", startDate: $graphStartDate) { newValue in
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
                .navigationTitle("Trend")
                .toolbarTitleDisplayMode(.inlineLarge)
                .refreshable {
                    await viewModel.refreshData()
                }
            }
        }
    }
}

// 構造体の外に配置
#Preview {
    GraphView(viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData))
}

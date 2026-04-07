//
//  MainTabView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/18.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = CalorieBalanceViewModel()
    
    var body: some View {
        TabView {
            // タブ1：日々のリスト画面
            // 修正：タイトルを String(localized:) で多言語化
            Tab(String(localized: "Daily"), systemImage: "list.bullet.clipboard") {
                DailyView(viewModel: viewModel)
                    .tint(nil)
            }
            
            // タブ2：トレンド画面
            // 修正：タイトルを String(localized:) で多言語化
            Tab(String(localized: "Trends"), systemImage: "chart.xyaxis.line") {
                GraphView(viewModel: viewModel)
                    .tint(nil)
            }
            
            // タブ3：目標画面
            // 修正：タイトルを String(localized:) で多言語化
            Tab(String(localized: "Goals"), systemImage: "flag.fill") {
                GoalView(viewModel: viewModel)
                    .tint(nil)
            }
        }
        .tint(.teal)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            // アプリ起動時にデータを取得
            viewModel.requestAccessAndFetchData()
        }
    }
}

#Preview {
    MainTabView()
}

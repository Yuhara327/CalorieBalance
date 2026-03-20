//
//  MainTabView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/18.
//

// メイン画面のタブ

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = CalorieBalanceViewModel()
    
    var body: some View {
        TabView {
            // タブ1：日々のリスト画面
            Tab("Daily", systemImage: "list.bullet.clipboard") {
                DailyView(viewModel: viewModel)
            }
            
            // タブ2：トレンド画面
            Tab("Trends", systemImage: "chart.xyaxis.line") {
                GraphView(viewModel: viewModel)
            }
        }
        .tint(.indigo)
        .task {
            viewModel.requestAccessAndFetchData()
        }
    }
}

#Preview {
    MainTabView()
}

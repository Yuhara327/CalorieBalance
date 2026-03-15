//
//  ContentView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalorieBalanceViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading{
                    ProgressView("データを取得中")
                }
                else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                else {
                    List(viewModel.dailyData, id: \.date) { data in
                        DailyCalorieRow(data: data)
                    }
                }
            }
            .navigationTitle("カロリーバランス")
            
            .task {
                viewModel.requestAccessAndFetchData()
            }
        }
    }
}

struct DailyCalorieRow: View {
    let data: CalorieData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDate(data.date))
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("消費カロリー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(data.totalBurnedCalories)) kcal")
                        .font(.subheadline)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("収支")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(data.netCalories))")
                        .font(.title)
                        .foregroundColor(data.netCalories <= 0 ? .green : .red)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("摂取カロリー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(data.dietaryCalories))kcal")
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding(.vertical)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}

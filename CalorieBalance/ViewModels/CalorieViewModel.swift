//
//  CalorieViewModel.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//
import Foundation
import Combine
import SwiftUI

@MainActor
class CalorieBalanceViewModel: ObservableObject {
    @Published var allData: [DailyMetrics] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date = Date()
    //開始日の「数字」は端末に保存する
    @AppStorage("dietStartDate") private var dietStartDateInterval : TimeInterval =
        Calendar.current.date(byAdding: .day, value: -29, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970 //便利な条件式である。
    //取得期間用の変数
    private var initialFetchDate: Date?
    //開始日の数字を時間型にしたり、時間型でユーザが変えたやつを数字にしたりする。つまりこいつがユーザーの設定した、ダイエットの開始日である。
    var dietStartDate: Date {
        get { Date(timeIntervalSince1970: dietStartDateInterval)}
        set { dietStartDateInterval = newValue.timeIntervalSince1970}
    }
    
    private let healhKitManager = HealthKitManager()
    
    //開始日から今日までの通算収支
    var totalNetCalories: Double {
        allData
            .filter { $0.date >= dietStartDate } // ダイエット開始日以降に絞る
            .compactMap { $0.netCalories }       // netCalories が nil の要素を除外（Double? -> Double）
            .reduce(0, +)
    }
    //selectedMonthに該当するデータを抽出
    var filteredData: [DailyMetrics] {
        let calendar = Calendar.current
        return allData.filter { data in
            calendar.isDate(data.date, equalTo: selectedMonth, toGranularity: .month)
        }.sorted(by: {$0.date > $1.date})
    }
    
    func requestAccessAndFetchData(customStartDate: Date? = nil) {
        Task {
            isLoading = true
            let fetchStart = min(customStartDate ?? dietStartDate, initialFetchDate ?? dietStartDate)// ややこしいが、とにかくロードしなきゃいけない最古の日を記録してる
            do {
                try await healhKitManager.requestAuthorization()
                
                let fetched = try await healhKitManager.fetchDailyCalories(startDate: fetchStart, endDate: Date())
                self.allData = fetched
                self.initialFetchDate = fetchStart
            } catch {
                self.errorMessage = "データの取得に失敗しました。: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
            
            let currentOldest = initialFetchDate ?? dietStartDate
            
            if selectedMonth < currentOldest {
                let calendar = Calendar.current
                if let startOfNewMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) {
                    requestAccessAndFetchData(customStartDate: startOfNewMonth)
                }
            }
        }
    }
}

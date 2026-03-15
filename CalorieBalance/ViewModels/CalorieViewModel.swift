//
//  CalorieViewModel.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//
import Foundation
import Combine

@MainActor
class CalorieBalanceViewModel: ObservableObject {
    @Published var dailyData: [CalorieData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let healhKitManager = HealthKitManager()
    
    func requestAccessAndFetchData() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                try await healhKitManager.requestAuthorization()
                
                let calendar = Calendar.current
                let endDate = Date()
                guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else {
                    isLoading = false
                    return
                }
                
                let fetchedData = try await healhKitManager.fetchDailyCalories(startDate: startDate, endDate: endDate)
                self.dailyData = fetchedData.sorted(by: {$0.date > $1.date})
            } catch {
                self.errorMessage = "データの取得に失敗しました。: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}

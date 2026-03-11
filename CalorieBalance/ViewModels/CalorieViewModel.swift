//
//  CalorieViewModel.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/11.
//

import Foundation
import Combine

class CalorieViewModel: ObservableObject { //ObservalObjectにしておくと、オブジェクトの状態が変化したときにViewに通知される
    @Published private(set) var calorieDataArray: [CalorieData] = [] //@PublishedもViewに通知。ViewModel外部からは読み込み専用
    private let healthkitManager = HealthKitManager()
    
    var totalConsumedCalories: Double{
        return calorieDataArray.reduce(0) { $0 + $1.totalCosumedCalories} //reduceで配列内の要素を順番に処理、初期値から累積輪を作成する。$0:累積値 $1:現在の要素
    }
    var totalNetCalories: Double {
        return calorieDataArray.reduce(0) { $0 + $1.netCalories}
    }
}

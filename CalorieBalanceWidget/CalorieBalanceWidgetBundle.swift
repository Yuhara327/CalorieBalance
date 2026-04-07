//
//  CalorieBalanceWidgetBundle.swift
//  CalorieBalanceWidget
//
//  Created by Soichiro Yuhara on 2026/04/02.
//

import WidgetKit
import SwiftUI

@main
struct CalorieBalanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalorieBalanceWidget()
        CalorieProgressWidget()
    }
}

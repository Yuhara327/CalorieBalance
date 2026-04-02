//
//  CalorieBalanceWidgetControl.swift
//  CalorieBalanceWidget
//
//  Created by Soichiro Yuhara on 2026/04/02.
//

import AppIntents
import SwiftUI
import WidgetKit

struct CalorieBalanceWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.yuhara.CalorieBalance.CalorieBalanceWidget",
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value,
                action: StartTimerIntent()
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

extension CalorieBalanceWidgetControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool {
            false
        }

        func currentValue() async throws -> Bool {
            let isRunning = true // Check if the timer is running
            return isRunning
        }
    }
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer is running")
    var value: Bool

    func perform() async throws -> some IntentResult {
        // Start / stop the timer based on `value`.
        return .result()
    }
}

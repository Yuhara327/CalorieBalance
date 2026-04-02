//
//  CalorieBalanceWidgetLiveActivity.swift
//  CalorieBalanceWidget
//
//  Created by Soichiro Yuhara on 2026/04/02.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CalorieBalanceWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CalorieBalanceWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CalorieBalanceWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension CalorieBalanceWidgetAttributes {
    fileprivate static var preview: CalorieBalanceWidgetAttributes {
        CalorieBalanceWidgetAttributes(name: "World")
    }
}

extension CalorieBalanceWidgetAttributes.ContentState {
    fileprivate static var smiley: CalorieBalanceWidgetAttributes.ContentState {
        CalorieBalanceWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CalorieBalanceWidgetAttributes.ContentState {
         CalorieBalanceWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CalorieBalanceWidgetAttributes.preview) {
   CalorieBalanceWidgetLiveActivity()
} contentStates: {
    CalorieBalanceWidgetAttributes.ContentState.smiley
    CalorieBalanceWidgetAttributes.ContentState.starEyes
}

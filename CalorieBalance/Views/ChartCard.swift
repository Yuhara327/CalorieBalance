//
//  ChartCard.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/19.
//

//グラフのガラスエフェクト、タイトル、日付選択のUIを管理する。
import SwiftUI

struct ChartCard<Content: View>: View {
    let title: String
    @Binding var startDate: Date
    let onDateChange: (Date) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack {
                    // String(localized:) を使用して多言語化に対応
                    Text(String(localized: "開始日"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .onChange(of: startDate) { _, newValue in
                onDateChange(newValue)
            }
            
            // ここに各グラフの具体的なChartや凡例が流し込まれる
            content()
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 30.0))
    }
}

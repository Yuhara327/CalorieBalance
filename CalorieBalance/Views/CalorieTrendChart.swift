//
//  CalorieTrendChart.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/19.
//

import SwiftUI
import Charts

struct CalorieTrendChart: View {
    @ObservedObject var viewModel: CalorieBalanceViewModel
    let graphStartDate: Date
    @Binding var selectedDate: Date?
    
    var body: some View {
        let trendData = viewModel.calculateCalorieTrend(from: graphStartDate)
        let axisValues = calculateAxisValues(startDate: graphStartDate)
        let dailyMax = trendData.map { abs($0.dailyNet) }.max() ?? 1000
        let cumulativeMax = trendData.map { abs($0.cumulativeNet) }.max() ?? 1000
        
        let dynamicScaleFactor: Double = {
            if dailyMax > 0 {
                return max(cumulativeMax / dailyMax, 1.0)
            } else {
                return 1.0
            }
        }()
        let averageNet = trendData.isEmpty ? 0 : trendData.map { $0.dailyNet }.reduce(0, +) / Double(trendData.count)
        
        VStack(alignment: .leading, spacing: 16) {
            // 凡例
            HStack(spacing: 16) {
                legendItem(label: String(localized: "消費超過"), color: .green, isLine: false)
                legendItem(label: String(localized: "摂取超過"), color: .red, isLine: false)
                legendItem(label: String(localized: "合計収支(右軸)"), color: .orange, isLine: true)
            }
            
            if trendData.isEmpty {
                Text(String(localized: "この期間のデータがありません")).foregroundColor(.secondary).frame(height: 250)
            } else {
                Chart {
                    ForEach(trendData) { item in
                        BarMark(x: .value("日付", item.date, unit: .day), y: .value("日次", item.dailyNet))
                            .foregroundStyle(item.dailyNet <= 0 ? .green : .red)
                    }
                    RuleMark(y: .value("平均", averageNet))
                        .foregroundStyle(.primary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            // 修正：ラベルと数値を一文にする
                            Text("平均: \(averageNet, format: .number.precision(.fractionLength(0)))")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    ForEach(trendData) { item in
                        LineMark(x: .value("日付", item.date, unit: .day), y: .value("合計", item.cumulativeNet / dynamicScaleFactor), series: .value("系列", "合計収支"))
                            .foregroundStyle(.orange)
                        PointMark(x: .value("日付", item.date, unit: .day), y: .value("合計", item.cumulativeNet / dynamicScaleFactor))
                            .foregroundStyle(.orange).symbolSize(30)
                    }
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(.separator).zIndex(-1)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXScale(domain: graphStartDate...Date())
                .chartXAxis {
                    AxisMarks(values: axisValues) { value in
                        if let date = value.as(Date.self) {
                            let day = Calendar.current.component(.day, from: date)
                            AxisGridLine()
                            if day != 1 {
                                AxisValueLabel(format: .dateTime.day())
                            } else {
                                AxisValueLabel(format: .dateTime.month(.narrow))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { value in
                        AxisGridLine()
                        if let kcal = value.as(Double.self) {
                            AxisValueLabel {
                                Text(Int(kcal), format: .number)
                            }
                        }
                    }
                    
                    AxisMarks(position: .trailing, values: .automatic) { value in
                        if let kcal = value.as(Double.self) {
                            AxisValueLabel {
                                // 修正：数値と単位を一つの Text で管理
                                let kValue = Int(kcal * dynamicScaleFactor / 1000)
                                Text("\(kValue)k")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let selectedDate, let data = trendData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                            let dateX = proxy.position(forX: data.date) ?? 0
                            popoverView(data: data)
                                .position(x: calculatePopoverX(dateX: dateX, geometry: geometry), y: 20)
                        }
                    }
                }
            }
            if !trendData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.needle")
                            .foregroundColor(.orange)
                        Text(String(localized: "期間中の平均収支"))
                            .font(.headline)
                    }
                    
                    Text(averageNet <= 0 ? String(localized: "アンダーカロリー継続中") : String(localized: "オーバーカロリー傾向"))
                        .font(.subheadline).bold()
                        .foregroundColor(averageNet <= 0 ? .green : .red)

                    // 重要修正：細切れにせず一文にする。Catalogには「この期間の1日平均は %f kcal です。」と登録されます。
                    Text("この期間の1日平均は \(averageNet, format: .number.precision(.fractionLength(0)).sign(strategy: .always())) kcal です。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(averageNet <= 0 ? String(localized: "このままのペースを維持することで、着実な体脂肪の減少が期待できます。") : String(localized: "摂取量が消費量を上回っています。このペースが維持されれば、体重の増加が見込まれます。"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func popoverView(data: CalorieChartData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.date, format: .dateTime.month().day().weekday()).font(.system(size: 15, weight: .bold))
            HStack(spacing: 12) {
                popoverValueStack(title: String(localized: "合計収支"), value: data.cumulativeNet, color: .orange)
                let dailyColor: Color = data.dailyNet <= 0 ? .green : .red
                popoverValueStack(title: String(localized: "日次収支"), value: data.dailyNet, color: dailyColor)
            }
        }
        .padding(8).background(.ultraThinMaterial).cornerRadius(8).shadow(radius: 2)
    }
    
    private func popoverValueStack(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 12)).foregroundColor(color)
            // 修正：ここも一つの文章として扱い、翻訳者が順序を変えられるようにする
            Text("\(Int(value)) kcal")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
        }
    }
    
    private func calculatePopoverX(dateX: CGFloat, geometry: GeometryProxy) -> CGFloat {
        let minX: CGFloat = 50
        let maxX: CGFloat = geometry.size.width - 50
        return min(max(dateX, minX), maxX)
    }
    
    private func legendItem(label: String, color: Color, isLine: Bool) -> some View {
        HStack(spacing: 6) {
            if isLine {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 18, height: 3)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.8))
                    .frame(width: 12, height: 12)
            }
            Text(label).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
        }
    }
    
    private func calculateAxisValues(startDate: Date) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: graphStartDate)
        let endDate = calendar.startOfDay(for: Date())
        let daysCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 30
        let dynamicStride: Int = {
            if daysCount <= 14 { return 2 }
            if daysCount <= 45 { return 5 }
            if daysCount <= 100 { return 15 }
            return 31
        }()
        
        while currentDate <= endDate {
            let day = calendar.component(.day, from: currentDate)
            if day == 1 {
                dates.append(currentDate)
            } else if day % dynamicStride == 0 {
                let isNearMonthEnd = day > 27
                let isNearMonthStart = day < 3
                if !isNearMonthEnd && !isNearMonthStart {
                    dates.append(currentDate)
                }
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dates
    }
}

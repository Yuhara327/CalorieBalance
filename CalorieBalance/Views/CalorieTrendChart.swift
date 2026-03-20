//
//  CalorieTrendChart.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/19.
//

// 収支カロリーのトレンドチャート

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
        // 合計収支が日次収支の何倍のレンジにあるかを計算
        // 最低でも 1.0 を確保し、0除算を防ぐ
        // 修正：dailyMax が 0 の場合に 0除算を避ける
        let dynamicScaleFactor: Double = {
            if dailyMax > 0 {
                return max(cumulativeMax / dailyMax, 1.0)
            } else {
                return 1.0
            }
        }()
        let averageNet = trendData.isEmpty ? 0 : trendData.map { $0.dailyNet }.reduce(0, +) / Double(trendData.count)
        
        VStack(alignment: .leading, spacing: 16) {
            // 凡例（体重専用）
            HStack(spacing: 16) {
                legendItem(label: "消費超過", color: .green, isLine: false)
                legendItem(label: "摂取超過", color: .red, isLine: false)
                legendItem(label: "合計収支(右軸)", color: .orange, isLine: true)
            }
            
            if trendData.isEmpty {
                Text("この期間のデータがありません").foregroundColor(.secondary).frame(height: 250)
            } else {
                Chart {
                    ForEach(trendData) { item in
                        BarMark(x: .value("日付", item.date, unit: .day), y: .value("日次", item.dailyNet))
                            .foregroundStyle(item.dailyNet <= 0 ? .green : .red)
                    }
                    RuleMark(y: .value("平均", averageNet))
                        .foregroundStyle(.primary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5])) // 点線にして主データと区別
                        .annotation(position: .top, alignment: .trailing) {
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
                    // 自身で計算した axisValues を直接渡す
                    AxisMarks(values: axisValues) { value in
                        if let date = value.as(Date.self) {
                            let day = Calendar.current.component(.day, from: date)
                            
                            AxisGridLine()
                            
                            // 1日は非表示にする、あるいは月名を表示するなどの制御が可能
                            if day != 1 {
                                AxisValueLabel(format: .dateTime.day())
                            } else {
                                // 1日の代わりに月を表示すると、より親切です（不要なら空文字）
                                AxisValueLabel(format: .dateTime.month(.narrow))
                            }
                        }
                    }
                }
                .chartYAxis {
                    // 左側の軸：日次収支用
                    AxisMarks(position: .leading, values: .automatic) { value in
                        AxisGridLine()
                        if let kcal = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(kcal))") // 小さい単位
                            }
                        }
                    }
                    
                    // 右側の軸：合計収支用
                    AxisMarks(position: .trailing, values: .automatic) { value in
                        if let kcal = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(kcal * dynamicScaleFactor / 1000))k") // 単位をk(キロ)にしてスッキリさせる
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
            if let averageNet = trendData.isEmpty ? nil : trendData.map({ $0.dailyNet }).reduce(0, +) / Double(trendData.count) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "gauge.with.needle")
                                        .foregroundColor(.orange)
                                    Text("期間中の平均収支")
                                        .font(.headline)
                                }
                                // 収支状況の言語化
                                // アンダー（マイナス）なら消費超過（痩せやすい）、オーバー（プラス）なら摂取超過（太りやすい）
                                Text(averageNet <= 0 ? "アンダーカロリー継続中" : "オーバーカロリー傾向")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(averageNet <= 0 ? .green : .red)

                                // 最新のSwiftUIの流儀に則った、文字列補完による安全な表示
                                Text("この期間の1日平均は \(Text(String(format: "%+.0f kcal", averageNet)).bold()) です。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(averageNet <= 0 ? "このままのペースを維持することで、着実な体脂肪の減少が期待できます。" : "摂取量が消費量を上回っています。このペースが維持されれば、体重の増加が見込まれます。")
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
    
    // --- 以下、専用のヘルパー関数群 ---
    private func popoverView(data: CalorieChartData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.date, format: .dateTime.month().day().weekday()).font(.system(size: 15, weight: .bold))
            HStack(spacing: 12) {
                popoverValueStack(title: "合計収支", value: data.cumulativeNet, color: .orange)
                let dailyColor: Color = data.dailyNet <= 0 ? .green : .red
                popoverValueStack(title: "日次収支", value: data.dailyNet, color: dailyColor)
            }
        }
        .padding(8).background(.ultraThinMaterial).cornerRadius(8).shadow(radius: 2)
    }
    
    private func popoverValueStack(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 12)).foregroundColor(color)
            Text("\(String(format: "%.0f", value))").font(.system(size: 15, weight: .bold, design: .monospaced))
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
                // 折れ線を模した横長のデザイン
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 18, height: 3)
            } else {
                // 棒グラフやプロット点を模したデザイン
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.8))
                    .frame(width: 12, height: 12)
            }
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
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
            
            // 1日は無条件に追加
            if day == 1 {
                dates.append(currentDate)
            }
            // 指定の間隔（5, 10...）の場合
            else if day % dynamicStride == 0 {
                // 前後の日付を確認し、1日と近すぎる（例：2日前後、あるいは月末付近）場合は追加しない
                // これにより「30」と「次月1日」の衝突を防ぐ
                let isNearMonthEnd = day > 27 // 月末付近の数字は1日と被りやすいので捨てる
                let isNearMonthStart = day < 3 // 月初付近も同様
                
                if !isNearMonthEnd && !isNearMonthStart {
                    dates.append(currentDate)
                }
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        return dates
    }
}


#Preview {
    // プレビュー用に一時的な状態を保持する場所がないため、
    // シンプルに表示を確認するだけなら .constant を使います。
    CalorieTrendChart(
        viewModel: CalorieBalanceViewModel(previewData: DailyMetrics.mockData),
        graphStartDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
        selectedDate: .constant(nil) // Bindingへの暫定対応
    )
    .padding()
    .background(Color.black.opacity(0.1)) // グラフを見やすくするための背景
}


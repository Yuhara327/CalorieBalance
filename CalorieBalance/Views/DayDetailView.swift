//
//  DayDetailView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/16.
//
import SwiftUI

struct DayDetailView: View {
    let metrics: DailyMetrics
    
    // 統一されたデザイン定数
    private let glassCornerRadius: CGFloat = 30.0
    private let panelPadding: CGFloat = 16.0
    
    var body: some View {
        ZStack {
            // 最背面：共通の高度なグラデーション背景
            AdvancedBackgroundView()
            
            ScrollView {
                VStack(spacing: 28) {
                    
                    // --- セクション1：エネルギー ---
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("エネルギー")
                        
                        VStack(spacing: 0) {
                            // 収支
                            energyRow(
                                icon: "chart.bar.fill",
                                title: "収支",
                                value: metrics.netCalories != nil ? String(format: "%.0f kcal", metrics.netCalories!) : "データなし",
                                color: metrics.netColor,
                                isLarge: true
                            )
                            
                            Divider().padding(.horizontal, panelPadding)
                            
                            // 消費
                            energyRow(
                                icon: "flame.fill",
                                title: "消費",
                                value: metrics.totalBurnedCalories != nil ? String(format: "%.0f kcal", metrics.totalBurnedCalories!) : "データなし",
                                color: .green
                            )
                            
                            Divider().padding(.horizontal, panelPadding)
                            
                            // 摂取
                            energyRow(
                                icon: "carrot.fill",
                                title: "摂取",
                                value: metrics.dietaryCalories != nil ? String(format: "%.0f kcal", metrics.dietaryCalories!) : "データなし",
                                color: .red
                            )
                        }
                        .glassEffect(in: .rect(cornerRadius: glassCornerRadius))
                    }
                    
                    // --- セクション2：ヘルスケアデータ ---
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("この日のヘルスケアデータ")
                        
                        VStack(spacing: 0) {
                            // 睡眠
                            healthRow(
                                icon: "bed.double.fill",
                                title: "睡眠",
                                value: metrics.sleepSeconds != nil ? String(format: "%.1f 時間", metrics.sleepSeconds! / 3600) : "データなし",
                                color: .indigo,
                                isMulticolor: true
                            )
                            
                            Divider().padding(.horizontal, panelPadding)
                            
                            // 歩数
                            healthRow(
                                icon: "figure.walk",
                                title: "歩数",
                                value: metrics.steps != nil ? String(format: "%i 歩", metrics.steps!) : "データなし",
                                color: .orange
                            )
                            
                            Divider().padding(.horizontal, panelPadding)

                            healthRow(icon: "scalemass.fill",
                                      title: "体重",
                                      value: metrics.weight != nil ? String(format:"%.1f kg", metrics.weight!) : "データなし",
                                      color: .teal)
                        }
                        .glassEffect(in: .rect(cornerRadius: glassCornerRadius))
                    }
                    
                    // 最下部の視覚的バッファ
                    Color.clear.frame(height: 40)
                }
                .padding()
            }
        }
        .navigationTitle(metrics.date.formatted(date: .numeric, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // --- ヘルパーメソッド：セクションヘッダー ---
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.primary.opacity(0.8))
            .bold()
            .padding(.leading, 8)
    }
    
    // --- ヘルパーメソッド：エネルギー行 ---
    @ViewBuilder
    private func energyRow(icon: String, title: String, value: String, color: Color, isLarge: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .font(isLarge ? .largeTitle : .title)
                .frame(width: 44, alignment: .center) // アイコン幅を固定して文字開始位置を揃える
            
            Text(title)
                .font(isLarge ? .title2 : .title3)
                .bold()
            
            Spacer()
            
            Text(value)
                .font(isLarge ? .largeTitle : .title)
                .bold()
        }
        .foregroundColor(color)
        .padding(panelPadding)
    }
    
    // --- ヘルパーメソッド：ヘルスケア行（精密アライメント版） ---
    @ViewBuilder
    private func healthRow(icon: String, title: String, value: String, color: Color, isMulticolor: Bool = false) -> some View {
        HStack {
            // 左側のラベルエリア（アイコンと文字を統合して幅を固定）
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .symbolRenderingMode(isMulticolor ? .multicolor : .monochrome)
                    .frame(width: 44, alignment: .center) // 睡眠と歩数のアイコン中心を揃える
                
                Text(title)
                    .font(.title2)
                    .bold()
            }
            .foregroundColor(color)
            .frame(width: 140, alignment: .leading) // 全体のラベル幅を固定して右側を揃える
            
            Spacer()
            
            Text(value)
                .font(.largeTitle)
                .foregroundColor(color)
                .bold()
        }
        .padding(panelPadding)
    }
}

// --- Preview ---
#Preview {
    let sample = DailyMetrics(
        date: Date(),
        activeCalories: 600,
        restingCalories: 1500,
        dietaryCalories: 1800,
        steps: 10240,
        sleepSeconds: 27000,
        weight: 50.5
    )
    return NavigationStack {
        DayDetailView(metrics: sample)
    }
}

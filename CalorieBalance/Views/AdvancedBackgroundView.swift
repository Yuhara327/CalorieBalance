//
//  AdvancedBackgroundView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/03/16.
//
import SwiftUI

struct AdvancedBackgroundView: View {
    // 環境変数から現在のスキームを取得（デバッグやプレビューに便利ですが、基本は自動で色が変わります）
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // ベース背景：ライトなら白、ダークなら黒に自動で切り替わる
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // 左上のインディゴ
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.indigo.opacity(colorScheme == .dark ? 1.0 : 1.0), // ダークモード時は少し抑える
                    Color(.systemBackground).opacity(0.0) // 溶ける先も背景色に合わせる
                ]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 800
            )
            .ignoresSafeArea()
            
            // 右上のグリーン
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(colorScheme == .dark ? 0.5 : 0.5),
                    Color(.systemBackground).opacity(0.0)
                ]),
                center: .topTrailing,
                startRadius: 0,
                endRadius: 800
            )
            .ignoresSafeArea()
        }
    }
}

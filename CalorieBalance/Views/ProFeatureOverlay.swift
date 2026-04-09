//
//  ProFeatureOverlay.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on 2026/04/09.
//

import SwiftUI

struct ProFeatureOverlay: View {
    var title: String = String(localized: "Pro機能")
    var message: String = String(localized: "この機能を利用するにはProプランへの加入が必要です。高度な分析でダイエットを加速させましょう。")
    
    // 追加: Paywallを表示するための状態変数
    @State private var isShowingPaywall = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(colors: [.teal, .blue], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .teal.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2).bold()
                
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            }
            
            Button {
                // 修正: 状態を true にして Paywall を呼び出す
                isShowingPaywall = true
            } label: {
                Text(String(localized: "詳しく見る"))
                    .bold()
                    .frame(minWidth: 160)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20)
        )
        .padding(24)
        // 追加: 状態変数を監視してシートを表示する
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
                // シートを全画面ではなく、少し下げて背後が見えるようにするとUXが向上します
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.1).ignoresSafeArea()
        VStack {
            Text("背後のグラフ").font(.largeTitle).foregroundColor(.secondary)
        }
        
        ProFeatureOverlay()
    }
}

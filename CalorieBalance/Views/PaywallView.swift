//
//  PaywallView.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on [日付].
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subManager = SubscriptionManager.shared
    
    @State private var selectedProduct: Product?
    @State private var isPurchasing: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // --- 上部：スクロール可能な説明エリア ---
                    ScrollView {
                        VStack(spacing: 32) {
                            
                            // 1. フック（期待感を高める）
                            VStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.cyan, .teal], startPoint: .top, endPoint: .bottom)
                                    )
                                    .shadow(color: .cyan.opacity(0.4), radius: 15, y: 5)
                                
                                Text(String(localized: "CalorieBalance Pro"))
                                    .font(.title).bold()
                                    .foregroundColor(.white)
                                
                                Text(String(localized: "すべての機能を解放し、\n最短で理想の体型を手に入れましょう。"))
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.top, 10)
                            
                            // 2. 視覚的証明（イメージを見せる）
                            VStack(spacing: 12) {
                                Text(String(localized: "Pro版の機能"))
                                    .font(.caption).bold()
                                    .foregroundColor(.white.opacity(0.5))
                                
                                // 【修正】ScrollViewReaderを追加して初期スクロール位置を制御
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            screenshotImage(imageName: "pro_screenshot_weight")
                                                .id("image1") // IDを付与
                                            
                                            screenshotImage(imageName: "pro_screenshot_sleep")
                                                .id("image2") // IDを付与
                                            
                                            screenshotImage(imageName: "pro_screenshot_goal")
                                                .id("image3") // IDを付与
                                        }
                                        .padding(.horizontal, 24)
                                        // Viewが表示された瞬間に2枚目を中央にスクロールする
                                        .onAppear {
                                            // 少しだけ遅延させると、レイアウト完了後に確実にスクロールされる
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation {
                                                    proxy.scrollTo("image2", anchor: .center)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 3. 論理的説得（具体的な機能を提示）
                            VStack(alignment: .leading, spacing: 20) {
                                featureRow(icon: "chart.line.uptrend.xyaxis", color: .teal, title: String(localized: "体重予測グラフ"), description: String(localized: "日々のカロリー収支から未来の体重を予測します。"))
                                featureRow(icon: "bed.double.fill", color: .cyan, title: String(localized: "睡眠相関分析"), description: String(localized: "睡眠時間とカロリー収支の相関を可視化、数値化します。"))
                                featureRow(icon: "target", color: .teal, title: String(localized: "高度な目標管理"), description: String(localized: "進捗リングと専用ウィジェットでモチベーションを維持します。"))
                                featureRow(icon: "lock.open.fill", color: .cyan, title: String(localized: "全機能への無制限アクセス"), description: String(localized: "今後のアップデートで追加される機能もすべて利用可能です。"))
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                        }
                    }
                    
                    // --- 下部：固定エリア（プラン選択と決済ボタン） ---
                    VStack(spacing: 16) {
                        
                        if subManager.products.isEmpty {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(height: 80)
                        } else {
                            // プランを横並び（カード型）に配置
                            HStack(spacing: 12) {
                                ForEach(subManager.products, id: \.id) { product in
                                    planCard(for: product)
                                }
                            }
                        }
                        
                        // 課金ボタン
                        VStack(spacing: 12) {
                            Button {
                                guard let selected = selectedProduct else { return }
                                Task {
                                    isPurchasing = true
                                    do {
                                        try await subManager.purchase(selected)
                                        if subManager.isPremium {
                                            dismiss()
                                        }
                                    } catch {
                                        print("決済プロセス中断: \(error)")
                                    }
                                    isPurchasing = false
                                }
                            } label: {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                } else {
                                    Text(String(localized: "続ける"))
                                        .font(.headline).bold()
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                            }
                            .disabled(isPurchasing || selectedProduct == nil || subManager.products.isEmpty)
                            .background(
                                LinearGradient(colors: [.cyan, .teal], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                            .shadow(color: .teal.opacity(0.3), radius: 8, y: 4)
                            .opacity((isPurchasing || selectedProduct == nil) ? 0.5 : 1.0)
                            
                            // 復元処理とリンク
                            HStack(spacing: 16) {
                                Button(String(localized: "以前の購入を復元")) {
                                    Task {
                                        isPurchasing = true
                                        try? await AppStore.sync()
                                        await subManager.updateCustomerProductStatus()
                                        if subManager.isPremium {
                                            dismiss()
                                        }
                                        isPurchasing = false
                                    }
                                }
                                .disabled(isPurchasing)
                                
                                Link(String(localized: "利用規約"), destination: URL(string: "https://example.com/terms")!)
                                Link(String(localized: "プライバシー"), destination: URL(string: "https://example.com/privacy")!)
                            }
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(edges: .bottom)
                            .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.title3)
                    }
                    .disabled(isPurchasing)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                if selectedProduct == nil {
                    selectedProduct = subManager.products.first(where: { $0.id.contains("yearly") }) ?? subManager.products.last
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func screenshotImage(imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 170, height: 170)
            .clipped()
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .teal.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).bold()
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    @ViewBuilder
    private func planCard(for product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isYearly = product.id.contains("yearly")
        
        let planName = isYearly ? String(localized: "年間プラン") : String(localized: "月間プラン")
        let subtitle = isYearly ? String(localized: "１年間継続") : String(localized: "いつでも解約可")
        let badgeText = isYearly ? String(localized: "2ヶ月分 お得") : nil
        
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedProduct = product
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text(planName)
                        .font(.subheadline).bold()
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    
                    Text(product.displayPrice)
                        .font(.title3).bold()
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .cyan : .white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                        .background(isSelected ? Color.cyan.opacity(0.1) : Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                )
                
                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}

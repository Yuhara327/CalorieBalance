//
//  SubscriptionManager.swift
//  CalorieBalance
//
//  Created by Soichiro Yuhara on [日付].
//

import Foundation
import StoreKit
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    // シングルトンインスタンス
    static let shared = SubscriptionManager()

    // 取得した商品（プラン）のリスト
    @Published var products: [Product] = []
    
    // 購入済みの商品ID
    @Published var purchasedProductIDs: Set<String> = []

    // ウィジェットと状態を共有するためのApp GroupのUserDefaults
    private let userDefaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance")

    // Pro権限のフラグ。変更されると自動的にApp Groupにも書き込まれ、ウィジェットが更新される。
    @Published var isPremium: Bool {
        didSet {
            userDefaults?.set(isPremium, forKey: "isPremium")
        }
    }

    // App Store Connect（または .storekit）に登録した商品ID
    private let productIDs: [String] = [
        "com.yuhara.CalorieBalance.monthly",
        "com.yuhara.CalorieBalance.yearly"
    ]

    // バックグラウンドでのトランザクション監視タスク
    private var updateListenerTask: Task<Void, Never>? = nil

    private init() {
        // アプリ起動時に、保存されている直近の状態を読み込む
        self.isPremium = userDefaults?.bool(forKey: "isPremium") ?? false
        
        // アプリ起動と同時にトランザクションの監視を開始
        updateListenerTask = listenForTransactions()
        
        Task {
            // 商品情報を取得し、現在の課金状態を確認する
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - 商品の取得
    func requestProducts() async {
        do {
            // Appleのサーバーから商品情報を取得
            let storeProducts = try await Product.products(for: productIDs)
            
            // 価格順（月額 -> 年額）にソートして保持
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed product request from the App Store server: \(error)")
        }
    }

    // MARK: - 購入処理
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Appleから返却されたトランザクションの電子署名を検証
            let transaction = try checkVerified(verification)
            
            // トランザクションを完了させる（Apple側に「商品を提供した」と伝える必須処理）
            await transaction.finish()
            
            // ユーザーの課金状態を再計算
            await updateCustomerProductStatus()
            
        case .userCancelled, .pending:
            break
        default:
            break
        }
    }

    // MARK: - 現在の課金状態の確認
    func updateCustomerProductStatus() async {
        var purchased: Set<String> = []

        // ユーザーが現在有効なサブスクリプション（Entitlements）をすべて取得
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // サブスクリプションが有効な（解約・期限切れでない）場合
                if transaction.productType == .autoRenewable {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }

        self.purchasedProductIDs = purchased
        
        // 1つでも有効なサブスクリプションがあればプレミアム権限を付与
        self.isPremium = !purchasedProductIDs.isEmpty
    }

    // MARK: - バックグラウンドトランザクションの監視
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            // アプリ外（設定アプリ等）での自動更新や解約を検知するストリーム
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updateCustomerProductStatus()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }

    // MARK: - トランザクションの署名検証
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // JWS (JSON Web Signature) の検証
        switch result {
        case .unverified:
            // 署名が不正（改ざんされている等）な場合は例外を投げる
            throw StoreError.failedVerification
        case .verified(let safe):
            // 署名が正当であればトランザクションデータを返す
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

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
import OSLog

@MainActor
class SubscriptionManager: ObservableObject {
    // シングルトンインスタンス
    static let shared = SubscriptionManager()

    // 取得した商品（プラン）のリスト
    @Published var products: [Product] = []
    
    // 購入済みの商品ID
    @Published var purchasedProductIDs: Set<String> = []

    // ウィジェットと状態を共有するためのApp GroupのUserDefaults
    private let userDefaults: UserDefaults?

    // Pro権限のフラグ。変更されると自動的にApp Groupにも書き込まれ、ウィジェットが更新される。
    @Published var isPremium: Bool {
        didSet {
            userDefaults?.set(isPremium, forKey: "isPremium")
        }
    }

    // App Store Connect（または .storekit）に登録した商品ID
    private static let productIDs: Set<String> = [
        "com.yuhara.CalorieBalance.monthly",
        "com.yuhara.CalorieBalance.yearly"
    ]

    private enum DefaultsKey {
        static let verifiedProductID = "subscription.verifiedProductID.v1"
        static let verifiedExpirationDate = "subscription.verifiedExpirationDate.v1"
        static let verifiedPurchaseDate = "subscription.verifiedPurchaseDate.v1"
        static let verifiedTransactionID = "subscription.verifiedTransactionID.v1"
        static let verifiedSubscriptionGroupID = "subscription.verifiedSubscriptionGroupID.v1"
    }

    nonisolated private static let logger = Logger(
        subsystem: "com.yuhara.CalorieBalance",
        category: "StoreKit"
    )

    // バックグラウンドでのトランザクション監視タスク
    private var updateListenerTask: Task<Void, Never>? = nil

    private static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private init() {
        let defaults = UserDefaults(suiteName: "group.yuhara.CalorieBalance")
        self.userDefaults = defaults

        // Previewでは課金状態の取得を行わず、Pro機能を常に確認できるようにする。
        if Self.isRunningForPreviews {
            self.isPremium = true
            return
        }

        // StoreKitが一時的に空の結果を返しても、直前に検証済みの購入を失わないようにする。
        // 単なるBool値は信頼せず、商品IDと有効期限を再評価する。
        let cachedEntitlement = Self.loadValidCachedEntitlement(from: defaults, now: Date())
        self.isPremium = cachedEntitlement != nil
        if let cachedEntitlement {
            self.purchasedProductIDs = [cachedEntitlement.productID]
        }
        defaults?.set(self.isPremium, forKey: "isPremium")

        if cachedEntitlement == nil {
            Self.clearCachedEntitlement(in: defaults)
        }
        
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
            let storeProducts = try await Product.products(for: Self.productIDs)
            
            // 価格順（月額 -> 年額）にソートして保持
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            let nsError = error as NSError
            Self.logger.error(
                "Product request failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code)"
            )
        }
    }

    // MARK: - 購入処理
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result: Product.PurchaseResult

        do {
            result = try await product.purchase()
        } catch {
            let nsError = error as NSError
            Self.logger.error(
                "Purchase failed for product ID \(product.id, privacy: .public): domain=\(nsError.domain, privacy: .public) code=\(nsError.code)"
            )
            throw error
        }

        switch result {
        case .success(let verification):
            // Appleから返却されたトランザクションの電子署名を検証
            let transaction = try checkVerified(verification)

            // 購入結果の検証済みトランザクションを直接評価する。
            // 権利の保存と提供が完了する前に finish() を呼ばない。
            guard grantsPremium(transaction, evidence: .datedTransaction, now: Date()) else {
                Self.logger.error(
                    "Verified purchase transaction is not an active known subscription for product ID: \(transaction.productID, privacy: .public)"
                )
                await transaction.finish()
                return .entitlementNotFound
            }

            applyActiveTransactions([transaction], source: .purchase)

            // Pro権限を保存・反映した後で、Apple側に提供完了を通知する。
            await transaction.finish()

            return .purchased
            
        case .userCancelled:
            return .cancelled

        case .pending:
            return .pending

        @unknown default:
            throw StoreError.unknownPurchaseResult
        }
    }

    // MARK: - 購入の復元
    func restorePurchases() async throws -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch {
            let nsError = error as NSError
            Self.logger.error(
                "App Store sync failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code)"
            )
            throw error
        }

        let status = await updateCustomerProductStatus()

        if status.hasActiveSubscription {
            return .restored
        }

        if status.hadVerificationFailure {
            throw StoreError.failedVerification
        }

        Self.logger.error("App Store sync completed, but no active subscription entitlement was returned")
        return .noActiveSubscription
    }

    // MARK: - 現在の課金状態の確認
    @discardableResult
    private func updateCustomerProductStatus() async -> EntitlementRefreshResult {
        let now = Date()

        // 1. Appleが現在の権利として返したトランザクションを最優先する。
        let currentLookup = await lookupCurrentEntitlements(now: now)
        if !currentLookup.activeTransactions.isEmpty {
            applyActiveTransactions(currentLookup.activeTransactions, source: .currentEntitlements)
            return EntitlementRefreshResult(
                hasActiveSubscription: true,
                hadVerificationFailure: currentLookup.hadVerificationFailure
            )
        }

        // 2. currentEntitlementsが空の場合は、サブスクリプショングループの状態を照会する。
        let statusLookup = await lookupSubscriptionStatuses(now: now)
        if !statusLookup.activeTransactions.isEmpty {
            applyActiveTransactions(statusLookup.activeTransactions, source: .subscriptionStatus)
            return EntitlementRefreshResult(
                hasActiveSubscription: true,
                hadVerificationFailure: currentLookup.hadVerificationFailure || statusLookup.hadVerificationFailure
            )
        }

        // 3. 状態APIも有効権利を返さない場合は、商品別の最新トランザクションを確認する。
        let latestLookup = await lookupLatestTransactions(now: now)
        if !latestLookup.activeTransactions.isEmpty {
            applyActiveTransactions(latestLookup.activeTransactions, source: .latestTransaction)
            return EntitlementRefreshResult(
                hasActiveSubscription: true,
                hadVerificationFailure: currentLookup.hadVerificationFailure
                    || statusLookup.hadVerificationFailure
                    || latestLookup.hadVerificationFailure
            )
        }

        let hadVerificationFailure = currentLookup.hadVerificationFailure
            || statusLookup.hadVerificationFailure
            || latestLookup.hadVerificationFailure

        // 検証不能なStoreKit情報がある場合、保存値だけで権利を付与しない。
        if hadVerificationFailure {
            setInactive()
            return EntitlementRefreshResult(
                hasActiveSubscription: false,
                hadVerificationFailure: true
            )
        }

        let explicitlyInactiveTransactions = statusLookup.inactiveTransactions
            + latestLookup.inactiveTransactions

        // 4. 全ライブAPIが空または取得不能のときだけ、以前に検証済みの購入を期限内で利用する。
        if let cachedEntitlement = loadValidCachedEntitlement(now: now),
           !isExplicitlyInvalidated(cachedEntitlement, by: explicitlyInactiveTransactions) {
            applyCachedEntitlement(cachedEntitlement)
            return EntitlementRefreshResult(
                hasActiveSubscription: true,
                hadVerificationFailure: false
            )
        }

        if let cachedEntitlement = loadValidCachedEntitlement(now: now),
           isExplicitlyInvalidated(cachedEntitlement, by: explicitlyInactiveTransactions) {
            clearCachedEntitlement()
        }

        setInactive()
        return EntitlementRefreshResult(
            hasActiveSubscription: false,
            hadVerificationFailure: false
        )
    }

    // MARK: - バックグラウンドトランザクションの監視
    private func listenForTransactions() -> Task<Void, Never> {
        return Task { [weak self] in
            // アプリ外（設定アプリ等）での自動更新や解約を検知するストリーム
            for await result in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try self.checkVerified(result)

                    guard Self.productIDs.contains(transaction.productID) else {
                        Self.logger.error(
                            "Ignoring transaction update for unknown product ID: \(transaction.productID, privacy: .public)"
                        )
                        continue
                    }

                    // 更新・新規購入も、権利の反映を終えてからfinishする。
                    if self.grantsPremium(transaction, evidence: .datedTransaction, now: Date()) {
                        self.applyActiveTransactions([transaction], source: .transactionUpdate)
                        await transaction.finish()
                        continue
                    }

                    // 取消・期限切れ通知は保存値を失効させ、他の有効プランがないか再照会する。
                    self.clearCachedEntitlement(ifMatching: transaction.productID)
                    await transaction.finish()
                    await self.updateCustomerProductStatus()
                } catch {
                    Self.logger.error("Transaction update failed verification")
                }
            }
        }
    }

    // MARK: - 権利情報の照合

    private func lookupCurrentEntitlements(now: Date) async -> EntitlementLookupResult {
        var lookup = EntitlementLookupResult()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard Self.productIDs.contains(transaction.productID) else { continue }

                if grantsPremium(transaction, evidence: .currentEntitlement, now: now) {
                    lookup.activeTransactions.append(transaction)
                }
            } catch {
                lookup.hadVerificationFailure = true
                Self.logger.error("Transaction verification failed while refreshing current entitlements")
            }
        }

        return lookup
    }

    private func lookupSubscriptionStatuses(now: Date) async -> EntitlementLookupResult {
        var lookup = EntitlementLookupResult()
        var queriedGroupIDs: Set<String> = []

        for product in products {
            guard let subscription = product.subscription,
                  queriedGroupIDs.insert(subscription.subscriptionGroupID).inserted else {
                continue
            }

            do {
                let statuses = try await subscription.status

                for status in statuses {
                    do {
                        // 状態の根拠となるトランザクションと更新情報の双方を検証する。
                        let transaction = try checkVerified(status.transaction)
                        _ = try checkVerified(status.renewalInfo)

                        guard Self.productIDs.contains(transaction.productID) else { continue }

                        let isEntitled = status.state == .subscribed || status.state == .inGracePeriod
                        if grantsPremium(
                            transaction,
                            evidence: .subscriptionStatus(isEntitled: isEntitled),
                            now: now
                        ) {
                            lookup.activeTransactions.append(transaction)
                        } else {
                            lookup.inactiveTransactions.append(transaction)
                        }
                    } catch {
                        lookup.hadVerificationFailure = true
                        Self.logger.error("Subscription status failed verification")
                    }
                }
            } catch {
                lookup.hadLookupFailure = true
                let nsError = error as NSError
                Self.logger.error(
                    "Subscription status lookup failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code)"
                )
            }
        }

        return lookup
    }

    private func lookupLatestTransactions(now: Date) async -> EntitlementLookupResult {
        var lookup = EntitlementLookupResult()

        for productID in Self.productIDs.sorted() {
            guard let result = await Transaction.latest(for: productID) else { continue }

            do {
                let transaction = try checkVerified(result)

                guard transaction.productID == productID else {
                    lookup.hadVerificationFailure = true
                    Self.logger.error(
                        "Latest transaction product mismatch for requested product ID: \(productID, privacy: .public)"
                    )
                    continue
                }

                if grantsPremium(transaction, evidence: .datedTransaction, now: now) {
                    lookup.activeTransactions.append(transaction)
                } else {
                    lookup.inactiveTransactions.append(transaction)
                }
            } catch {
                lookup.hadVerificationFailure = true
                Self.logger.error(
                    "Latest transaction failed verification for product ID: \(productID, privacy: .public)"
                )
            }
        }

        return lookup
    }

    private func grantsPremium(
        _ transaction: StoreKit.Transaction,
        evidence: SubscriptionEntitlementEvidence,
        now: Date
    ) -> Bool {
        SubscriptionEntitlementPolicy.grantsPremium(
            facts: SubscriptionEntitlementFacts(
                productID: transaction.productID,
                isAutoRenewable: transaction.productType == .autoRenewable,
                revocationDate: transaction.revocationDate,
                expirationDate: transaction.expirationDate
            ),
            evidence: evidence,
            allowedProductIDs: Self.productIDs,
            now: now
        )
    }

    // MARK: - 権利状態の保存と反映

    private func applyActiveTransactions(
        _ transactions: [StoreKit.Transaction],
        source: EntitlementSource
    ) {
        let activeProductIDs = Set(transactions.map(\.productID))
        guard !activeProductIDs.isEmpty else { return }

        purchasedProductIDs = activeProductIDs
        isPremium = true

        if let cacheCandidate = transactions
            .filter({ grantsPremium($0, evidence: .datedTransaction, now: Date()) })
            .max(by: {
                ($0.expirationDate ?? .distantPast) < ($1.expirationDate ?? .distantPast)
            }),
           let expirationDate = cacheCandidate.expirationDate {
            saveCachedEntitlement(
                CachedEntitlement(
                    productID: cacheCandidate.productID,
                    expirationDate: expirationDate,
                    purchaseDate: cacheCandidate.purchaseDate,
                    transactionID: cacheCandidate.id,
                    subscriptionGroupID: cacheCandidate.subscriptionGroupID
                )
            )
        }

        Self.logger.info(
            "Premium entitlement applied from \(source.rawValue, privacy: .public); product count=\(activeProductIDs.count)"
        )
    }

    private func applyCachedEntitlement(_ entitlement: CachedEntitlement) {
        purchasedProductIDs = [entitlement.productID]
        isPremium = true
        Self.logger.info(
            "Premium entitlement applied from \(EntitlementSource.cachedVerifiedTransaction.rawValue, privacy: .public)"
        )
    }

    private func setInactive() {
        purchasedProductIDs = []
        isPremium = false
    }

    private func saveCachedEntitlement(_ entitlement: CachedEntitlement) {
        userDefaults?.set(entitlement.productID, forKey: DefaultsKey.verifiedProductID)
        userDefaults?.set(entitlement.expirationDate, forKey: DefaultsKey.verifiedExpirationDate)
        userDefaults?.set(entitlement.purchaseDate, forKey: DefaultsKey.verifiedPurchaseDate)
        userDefaults?.set(String(entitlement.transactionID), forKey: DefaultsKey.verifiedTransactionID)

        if let subscriptionGroupID = entitlement.subscriptionGroupID {
            userDefaults?.set(subscriptionGroupID, forKey: DefaultsKey.verifiedSubscriptionGroupID)
        } else {
            userDefaults?.removeObject(forKey: DefaultsKey.verifiedSubscriptionGroupID)
        }
    }

    private func loadValidCachedEntitlement(now: Date) -> CachedEntitlement? {
        guard let entitlement = Self.loadValidCachedEntitlement(from: userDefaults, now: now) else {
            clearCachedEntitlement()
            return nil
        }
        return entitlement
    }

    private static func loadValidCachedEntitlement(
        from defaults: UserDefaults?,
        now: Date
    ) -> CachedEntitlement? {
        guard let productID = defaults?.string(forKey: DefaultsKey.verifiedProductID),
              let expirationDate = defaults?.object(forKey: DefaultsKey.verifiedExpirationDate) as? Date,
              let purchaseDate = defaults?.object(forKey: DefaultsKey.verifiedPurchaseDate) as? Date,
              let transactionIDString = defaults?.string(forKey: DefaultsKey.verifiedTransactionID),
              let transactionID = UInt64(transactionIDString) else {
            return nil
        }

        let facts = SubscriptionEntitlementFacts(
            productID: productID,
            isAutoRenewable: true,
            revocationDate: nil,
            expirationDate: expirationDate
        )

        guard SubscriptionEntitlementPolicy.grantsPremium(
            facts: facts,
            evidence: .datedTransaction,
            allowedProductIDs: productIDs,
            now: now
        ) else {
            return nil
        }

        return CachedEntitlement(
            productID: productID,
            expirationDate: expirationDate,
            purchaseDate: purchaseDate,
            transactionID: transactionID,
            subscriptionGroupID: defaults?.string(forKey: DefaultsKey.verifiedSubscriptionGroupID)
        )
    }

    private func isExplicitlyInvalidated(
        _ cachedEntitlement: CachedEntitlement,
        by transactions: [StoreKit.Transaction]
    ) -> Bool {
        transactions.contains { transaction in
            let isSameSubscription: Bool

            if let cachedGroupID = cachedEntitlement.subscriptionGroupID,
               let transactionGroupID = transaction.subscriptionGroupID {
                isSameSubscription = cachedGroupID == transactionGroupID
            } else {
                isSameSubscription = cachedEntitlement.productID == transaction.productID
            }

            guard isSameSubscription else { return false }

            // 同一トランザクションの取消・請求状態変更、またはそれより新しい状態だけが
            // 保存済みの検証済み購入を失効させる。StoreKitが古い履歴を返した場合は無視する。
            return transaction.id == cachedEntitlement.transactionID
                || transaction.purchaseDate >= cachedEntitlement.purchaseDate
        }
    }

    private func clearCachedEntitlement(ifMatching productID: String? = nil) {
        if let productID,
           userDefaults?.string(forKey: DefaultsKey.verifiedProductID) != productID {
            return
        }
        Self.clearCachedEntitlement(in: userDefaults)
    }

    private func clearCachedEntitlement() {
        Self.clearCachedEntitlement(in: userDefaults)
    }

    private static func clearCachedEntitlement(in defaults: UserDefaults?) {
        defaults?.removeObject(forKey: DefaultsKey.verifiedProductID)
        defaults?.removeObject(forKey: DefaultsKey.verifiedExpirationDate)
        defaults?.removeObject(forKey: DefaultsKey.verifiedPurchaseDate)
        defaults?.removeObject(forKey: DefaultsKey.verifiedTransactionID)
        defaults?.removeObject(forKey: DefaultsKey.verifiedSubscriptionGroupID)
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
    case unknownPurchaseResult
}

enum PurchaseOutcome {
    case purchased
    case pending
    case cancelled
    case entitlementNotFound
}

enum RestoreOutcome {
    case restored
    case noActiveSubscription
}

private struct EntitlementRefreshResult {
    let hasActiveSubscription: Bool
    let hadVerificationFailure: Bool
}

private struct EntitlementLookupResult {
    var activeTransactions: [StoreKit.Transaction] = []
    var inactiveTransactions: [StoreKit.Transaction] = []
    var hadVerificationFailure = false
    var hadLookupFailure = false
}

private struct CachedEntitlement {
    let productID: String
    let expirationDate: Date
    let purchaseDate: Date
    let transactionID: UInt64
    let subscriptionGroupID: String?
}

private enum EntitlementSource: String {
    case purchase = "PURCHASE_TRANSACTION"
    case currentEntitlements = "CURRENT_ENTITLEMENTS"
    case subscriptionStatus = "SUBSCRIPTION_STATUS"
    case latestTransaction = "LATEST_TRANSACTION"
    case cachedVerifiedTransaction = "CACHED_VERIFIED_TRANSACTION"
    case transactionUpdate = "TRANSACTION_UPDATE"
}

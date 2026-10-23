//
//  SubscriptionEntitlementPolicy.swift
//  CalorieBalance
//

import Foundation

/// StoreKitから得た事実を、Pro権限に変換するための純粋な判定ロジック。
/// StoreKit型から分離し、期限・取消・商品IDの境界条件を単体で検証できるようにする。
struct SubscriptionEntitlementFacts {
    let productID: String
    let isAutoRenewable: Bool
    let revocationDate: Date?
    let expirationDate: Date?
}

enum SubscriptionEntitlementEvidence {
    /// `Transaction.currentEntitlements` 自体が有効権利だけを返すため、
    /// grace period中はトランザクションの有効期限を過ぎていても権利を認める。
    case currentEntitlement

    /// サブスクリプション状態APIの更新状態を明示的に反映する。
    case subscriptionStatus(isEntitled: Bool)

    /// 購入結果、商品別の最新トランザクション、保存済み購入情報では日付を判定する。
    case datedTransaction
}

struct SubscriptionEntitlementPolicy {
    static func grantsPremium(
        facts: SubscriptionEntitlementFacts,
        evidence: SubscriptionEntitlementEvidence,
        allowedProductIDs: Set<String>,
        now: Date
    ) -> Bool {
        guard allowedProductIDs.contains(facts.productID),
              facts.isAutoRenewable,
              facts.revocationDate == nil else {
            return false
        }

        switch evidence {
        case .currentEntitlement:
            return true

        case .subscriptionStatus(let isEntitled):
            return isEntitled

        case .datedTransaction:
            guard let expirationDate = facts.expirationDate else {
                return false
            }
            return expirationDate > now
        }
    }
}

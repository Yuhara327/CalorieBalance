import Foundation

@main
struct SubscriptionEntitlementPolicyChecks {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000)
        let allowedProductIDs: Set<String> = ["monthly", "yearly"]

        check(
            "active verified purchase",
            facts: facts(productID: "monthly", expirationDate: now.addingTimeInterval(60)),
            evidence: .datedTransaction,
            allowedProductIDs: allowedProductIDs,
            now: now,
            expected: true
        )
        check(
            "expired purchase",
            facts: facts(productID: "monthly", expirationDate: now),
            evidence: .datedTransaction,
            allowedProductIDs: allowedProductIDs,
            now: now,
            expected: false
        )
        check(
            "revoked purchase",
            facts: facts(
                productID: "monthly",
                revocationDate: now,
                expirationDate: now.addingTimeInterval(60)
            ),
            evidence: .datedTransaction,
            allowedProductIDs: allowedProductIDs,
            now: now,
            expected: false
        )
        check(
            "unknown product",
            facts: facts(productID: "other", expirationDate: now.addingTimeInterval(60)),
            evidence: .datedTransaction,
            allowedProductIDs: allowedProductIDs,
            now: now,
            expected: false
        )
        check(
            "non-renewing product",
            facts: facts(
                productID: "monthly",
                isAutoRenewable: false,
                expirationDate: now.addingTimeInterval(60)
            ),
            evidence: .datedTransaction,
            allowedProductIDs: allowedProductIDs,
            now: now,
            expected: false
        )
        check(
            "grace-period current entitlement",
            facts: facts(productID: "monthly", expirationDate: now.addingTimeInterval(-60)),
            evidence: .currentEntitlement,
            allowedProductIDs: allowedProductIDs,
            now: now,
            expected: true
        )
        check(
            "inactive subscription status",
            facts: facts(productID: "monthly", expirationDate: now.addingTimeInterval(60)),
            evidence: .subscriptionStatus(isEntitled: false),
            allowedProductIDs: allowedProductIDs,
            now: now,
            expected: false
        )

        print("7 subscription entitlement policy checks passed")
    }

    private static func facts(
        productID: String,
        isAutoRenewable: Bool = true,
        revocationDate: Date? = nil,
        expirationDate: Date?
    ) -> SubscriptionEntitlementFacts {
        SubscriptionEntitlementFacts(
            productID: productID,
            isAutoRenewable: isAutoRenewable,
            revocationDate: revocationDate,
            expirationDate: expirationDate
        )
    }

    private static func check(
        _ name: String,
        facts: SubscriptionEntitlementFacts,
        evidence: SubscriptionEntitlementEvidence,
        allowedProductIDs: Set<String>,
        now: Date,
        expected: Bool
    ) {
        let actual = SubscriptionEntitlementPolicy.grantsPremium(
            facts: facts,
            evidence: evidence,
            allowedProductIDs: allowedProductIDs,
            now: now
        )

        precondition(actual == expected, "Failed: \(name)")
    }
}

import Foundation
import Observation
import StoreKit

/// Access is derived exclusively from verified App Store entitlements, never UserDefaults.
@MainActor
@Observable
final class ProStore {
    static let monthlyID = "com.GregAdams.TimeBoxed.pro.monthly"
    static let lifetimeID = "com.GregAdams.TimeBoxed.pro.lifetime"
    static let productIDs = [monthlyID, lifetimeID]

    private(set) var hasPro = false
    private(set) var hasLifetime = false
    private(set) var isCheckingAccess = true
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var products: [Product] = []
    private(set) var message: String?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      Self.productIDs.contains(transaction.productID) else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func refreshEntitlements() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var activeIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded,
                  Self.productIDs.contains(transaction.productID) else { continue }
            // currentEntitlements includes subscribed and billing-grace-period access.
            activeIDs.insert(transaction.productID)
        }
        guard generation == refreshGeneration else { return }
        hasLifetime = activeIDs.contains(Self.lifetimeID)
        hasPro = !activeIDs.isEmpty
        isCheckingAccess = false
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        message = nil
        do {
            products = try await Product.products(for: Self.productIDs)
            if products.count < Self.productIDs.count {
                message = "Some purchase options are unavailable right now. Please try again later."
            }
        } catch {
            message = "Unable to load purchase options. Check your connection and try again."
        }
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing, !hasPro, Self.productIDs.contains(product.id) else { return }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    message = "This purchase could not be verified. Please try restoring purchases."
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
                message = hasPro ? "Pro is unlocked. Thank you for supporting Time Boxed!" : "Your purchase is processing. Try restoring purchases in a moment."
            case .pending:
                message = "Your purchase is awaiting approval. Pro will unlock once Apple confirms it."
            case .userCancelled:
                break
            @unknown default:
                message = "The purchase could not be completed. Please try again."
            }
        } catch {
            message = "The purchase could not be completed. \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = hasPro ? "Your Pro access has been restored." : "No active Pro purchase was found for this Apple Account."
        } catch {
            message = "Unable to restore purchases. \(error.localizedDescription)"
        }
    }
}

struct ProAccessPolicy {
    static func canView(_ date: Date, hasPro: Bool, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Bool {
        hasPro || calendar.isDate(date, inSameDayAs: now)
    }
}

//
//  HealthKitService.swift
//  NeuroCalm
//
//  Saves breathing sessions to Apple Health as Mindful Minutes.
//
//  IMPORTANT: For this to work you must:
//   1. Add the HealthKit capability to your target (Signing & Capabilities tab).
//   2. Add these keys to your Info.plist:
//        - NSHealthShareUsageDescription
//        - NSHealthUpdateUsageDescription
//

import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    /// The data we want to write — Apple's standard "Mindful Session" category.
    private var mindfulType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }

    /// Ask the user for permission to write Mindful Minutes.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(), let type = mindfulType else {
            completion(false)
            return
        }
        healthStore.requestAuthorization(toShare: [type], read: []) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    /// Save a completed breathing session to Apple Health.
    func saveMindfulMinutes(seconds: Int, completion: @escaping (Bool) -> Void) {
        guard let type = mindfulType, seconds > 0 else {
            completion(false); return
        }

        let end = Date()
        let start = end.addingTimeInterval(-Double(seconds))

        let sample = HKCategorySample(
            type: type,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        healthStore.save(sample) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}

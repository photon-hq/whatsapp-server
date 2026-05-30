import Foundation

enum WhatsAppDate {

    private static let appleReferenceOffset: TimeInterval = 978_307_200

    static func fromStoredSeconds(_ value: Double?) -> Date? {
        guard let value else {
            return nil
        }

        return Date(timeIntervalSince1970: value + appleReferenceOffset)
    }

    static func storedSeconds(from date: Date) -> Double {
        date.timeIntervalSince1970 - appleReferenceOffset
    }

}

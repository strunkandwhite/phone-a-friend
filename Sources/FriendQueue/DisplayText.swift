import Foundation

public enum DisplayText {
    public static func lastContact(_ record: FriendRecord?, today: DayKey) -> String {
        guard let lastContacted = record?.lastContacted else { return "Never contacted" }
        let days = today.days(since: lastContacted)
        switch days {
        case ...0: return "Last contact: today"
        case 1: return "Last contact: yesterday"
        default: return "Last contact: \(days) days ago"
        }
    }
}

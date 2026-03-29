import Foundation
import EventKit

let store = EKEventStore()
let group = DispatchGroup()
group.enter()

let daysAhead = Int(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "3") ?? 3

store.requestFullAccessToEvents { granted, error in
    guard granted else {
        print("[]")
        group.leave()
        return
    }

    let cal = Calendar.current
    let now = Date()
    let startOfToday = cal.startOfDay(for: now)
    let endDate = cal.date(byAdding: .day, value: daysAhead, to: startOfToday)!

    let predicate = store.predicateForEvents(withStart: startOfToday, end: endDate, calendars: nil)
    let events = store.events(matching: predicate)

    let formatter = ISO8601DateFormatter()
    var result: [[String: String]] = []

    for event in events {
        result.append([
            "calendar": event.calendar.title,
            "title": event.title ?? "",
            "start": formatter.string(from: event.startDate),
            "end": formatter.string(from: event.endDate),
            "location": event.location ?? "",
            "notes": event.notes ?? ""
        ])
    }

    if let data = try? JSONSerialization.data(withJSONObject: result),
       let json = String(data: data, encoding: .utf8) {
        print(json)
    } else {
        print("[]")
    }
    group.leave()
}

group.wait()

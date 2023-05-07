import Foundation

extension Locale {
    static func is12HoursFormat() -> Bool {
        DateFormatter.dateFormat(fromTemplate: "j",
                                 options: 0,
                                 locale: Locale.current)?.ranges(of: "a") != nil
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .full
    formatter.locale = .current
    formatter.dateFormat = "MMM dd, yyyy 'at' h:mm:ss a zzz"
    return formatter
}()

let dateFormatter24: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .long
    formatter.dateFormat = "MMM dd, yyyy 'at' HH:mm:ss zzz"
    return formatter
}()



let date = Date()
let dateString24 = dateFormatter24.string(from: date)
let date24 = dateFormatter24.date(from: dateString24)

dateFormatter.date(from: dateFormatter.string(from: Date()))

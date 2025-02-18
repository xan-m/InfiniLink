//
//  Date+Extension.swift
//  InfiniLink
//
//  Created by Liam Willey on 10/10/24.
//

import Foundation

extension Date {
    func comparable() -> String {
        return self.formatted(.dateTime.dayOfYear())
    }
    
    static var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components)!
    }
    
    static var endOfMonth: Date {
        let calendar = Calendar.current
        let startOfMonth = Date.startOfMonth
        let components = DateComponents(month: 1, day: -1)
        return calendar.date(byAdding: components, to: startOfMonth)!
    }
    
    static func monthFromInt(_ month: Int) -> String {
        let monthSymbols = Calendar.current.monthSymbols
        return monthSymbols[month]
    }
    
    static func monthAbbreviationFromInt(_ month: Int) -> String {
        let monthSymbols = Calendar.current.shortMonthSymbols
        return monthSymbols[month]
    }
    
    static func getDateFrom(month: Int) -> Date {
        var components = DateComponents()
        components.month = month
        
        let calendar = Calendar.current
        components.year = calendar.component(.year, from: Date())
        components.day = 1
        
        return calendar.date(from: components) ?? Date()
    }
    
    static func from(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: components)!
    }
}

func date(year: Int, month: Int, day: Int = 1, hour: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minutes, second: seconds)) ?? Date()
}

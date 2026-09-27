import Foundation

public enum DayScheduleCategory: String, CaseIterable, Identifiable {
    case workday = "工作日"
    case holiday = "节假日"
    case weekend = "普通周末"
    
    public var id: String { rawValue }
}

public struct DayAttribute {
    public let date: Date
    public let category: DayScheduleCategory
    public let name: String?
    public let isAdjustedWorkday: Bool  // 周末调休上班
    public let isStatutoryHoliday: Bool // 法定放假
    
    public var badgeText: String {
        if isAdjustedWorkday {
            return name ?? "调休上班"
        } else if isStatutoryHoliday {
            return name ?? "法定假期"
        } else {
            return category.rawValue
        }
    }
}

public final class HolidayManager {
    public static let shared = HolidayManager()
    
    // YYYY-MM-DD -> 节假日名称
    private var statutoryHolidays: [String: String] = [:]
    
    // YYYY-MM-DD -> 调休上班说明（原为周末，因调休需正常上班）
    private var adjustedWorkdays: [String: String] = [:]
    
    private init() {
        loadPresetHolidayData()
    }
    
    // MARK: - Core Query Interface
    
    public func getDayAttribute(for date: Date) -> DayAttribute {
        let comp = Calendar.current.dateComponents([.year, .month, .day, .weekday], from: date)
        let key = String(format: "%04d-%02d-%02d", comp.year ?? 0, comp.month ?? 0, comp.day ?? 0)
        let weekday = comp.weekday ?? 1 // 1: 周日, 7: 周六
        let isStandardWeekend = (weekday == 1 || weekday == 7)
        
        // 1. 优先判定是否为周末调休上班日
        if let desc = adjustedWorkdays[key] {
            return DayAttribute(
                date: date,
                category: .workday,
                name: desc,
                isAdjustedWorkday: true,
                isStatutoryHoliday: false
            )
        }
        
        // 2. 判定是否为法定节假日（无论平时还是周末）
        if let holidayName = statutoryHolidays[key] {
            return DayAttribute(
                date: date,
                category: .holiday,
                name: holidayName,
                isAdjustedWorkday: false,
                isStatutoryHoliday: true
            )
        }
        
        // 3. 常规日期划分：周六日为周末，周一至周五为工作日
        if isStandardWeekend {
            return DayAttribute(
                date: date,
                category: .weekend,
                name: nil,
                isAdjustedWorkday: false,
                isStatutoryHoliday: false
            )
        } else {
            return DayAttribute(
                date: date,
                category: .workday,
                name: nil,
                isAdjustedWorkday: false,
                isStatutoryHoliday: false
            )
        }
    }
    
    /// 根据用户智能选项，判定某天是否应按「工作日闹钟」响铃
    public func shouldTreatAsWorkday(
        date: Date,
        smartHoliday: Bool = true,
        smartWorkday: Bool = true
    ) -> Bool {
        let attr = getDayAttribute(for: date)
        
        // 如果是周末调休上班：开启智能补班时算工作日，否则按普通周末
        if attr.isAdjustedWorkday {
            return smartWorkday ? true : false
        }
        
        // 如果是法定节假日：开启智能休假时算休息日，否则按自然工作日判定
        if attr.isStatutoryHoliday {
            if smartHoliday {
                return false
            } else {
                // 不开启智能调休时，看它本身是否是周一至周五
                let weekday = Calendar.current.component(.weekday, from: date)
                return (weekday >= 2 && weekday <= 6)
            }
        }
        
        // 常规工作日 (周一至周五)
        return attr.category == .workday
    }
    
    // MARK: - Preset Chinese Statutory Holidays (2026 & 基础数据)
    
    private func loadPresetHolidayData() {
        // --- 2026年 法定节假日安排 ---
        // 元旦: 1.1 ~ 1.3 放假, 1.4 (周日) 调休上班
        statutoryHolidays["2026-01-01"] = "元旦"
        statutoryHolidays["2026-01-02"] = "元旦假期"
        statutoryHolidays["2026-01-03"] = "元旦假期"
        adjustedWorkdays["2026-01-04"] = "元旦调休上班"
        
        // 春节: 2.15 (除夕) ~ 2.23 (初七) 放假, 2.14 (周六) & 2.28 (周六) 调休上班
        adjustedWorkdays["2026-02-14"] = "春节调休上班"
        for day in 15...23 {
            statutoryHolidays[String(format: "2026-02-%02d", day)] = (day == 15 ? "除夕" : (day == 16 ? "春节初一" : "春节假期"))
        }
        adjustedWorkdays["2026-02-28"] = "春节调休上班"
        
        // 清明节: 4.4 ~ 4.6 放假
        statutoryHolidays["2026-04-04"] = "清明节"
        statutoryHolidays["2026-04-05"] = "清明假期"
        statutoryHolidays["2026-04-06"] = "清明假期"
        
        // 劳动节: 5.1 ~ 5.5 放假, 4.26 (周日) & 5.9 (周六) 调休上班
        adjustedWorkdays["2026-04-26"] = "五一调休上班"
        for day in 1...5 {
            statutoryHolidays[String(format: "2026-05-%02d", day)] = (day == 1 ? "劳动节" : "五一假期")
        }
        adjustedWorkdays["2026-05-09"] = "五一调休上班"
        
        // 端午节: 6.19 ~ 6.21 放假
        statutoryHolidays["2026-06-19"] = "端午节"
        statutoryHolidays["2026-06-20"] = "端午假期"
        statutoryHolidays["2026-06-21"] = "端午假期"
        
        // 中秋节: 9.25 ~ 9.27 放假
        statutoryHolidays["2026-09-25"] = "中秋节"
        statutoryHolidays["2026-09-26"] = "中秋假期"
        statutoryHolidays["2026-09-27"] = "中秋假期"
        
        // 国庆节: 10.1 ~ 10.7 放假, 9.27 或 10.10 (周六) 调休上班
        adjustedWorkdays["2026-10-10"] = "国庆调休上班"
        for day in 1...7 {
            statutoryHolidays[String(format: "2026-10-%02d", day)] = (day == 1 ? "国庆节" : "国庆假期")
        }
    }
}

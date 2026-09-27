import XCTest
@testable import MorningWake

final class MorningWakeTests: XCTestCase {
    
    // MARK: - FadeCurve Tests
    
    func testFadeCurveBoundaries() {
        for curve in FadeCurve.allCases {
            XCTAssertEqual(curve.transform(t: 0.0), 0.0, accuracy: 0.0001, "\(curve.rawValue) at t=0 应为 0")
            XCTAssertEqual(curve.transform(t: 1.0), 1.0, accuracy: 0.0001, "\(curve.rawValue) at t=1 应为 1")
            
            // 越界值保护测试
            XCTAssertEqual(curve.transform(t: -0.5), 0.0, accuracy: 0.0001)
            XCTAssertEqual(curve.transform(t: 1.5), 1.0, accuracy: 0.0001)
        }
    }
    
    func testFadeCurveMonotonicity() {
        // 验证三种曲线在 0.0 到 1.0 区间内单调递增
        for curve in FadeCurve.allCases {
            var previousValue = -1.0
            for step in 0...100 {
                let t = Double(step) / 100.0
                let val = curve.transform(t: t)
                XCTAssertGreaterThanOrEqual(val, previousValue, "\(curve.rawValue) 在 t=\(t) 处非单调递增")
                previousValue = val
            }
        }
    }
    
    func testSmoothStepCurveCharacteristics() {
        // smoothStep 具有 S 型两端平缓、中段平稳提升特征: 3t^2 - 2t^3
        let curve = FadeCurve.smoothStep
        XCTAssertEqual(curve.transform(t: 0.5), 0.5, accuracy: 0.0001)
        // t=0.25: 3*(1/16) - 2*(1/64) = 3/16 - 1/32 = 5/32 = 0.15625
        XCTAssertEqual(curve.transform(t: 0.25), 0.15625, accuracy: 0.0001)
    }
    
    // MARK: - RepeatSchedule Tests
    
    func testRepeatScheduleEnumCases() {
        XCTAssertEqual(RepeatSchedule.everyday.rawValue, "每天")
        XCTAssertEqual(RepeatSchedule.weekdays.rawValue, "仅工作日 (周一至周五)")
        XCTAssertEqual(RepeatSchedule.weekends.rawValue, "仅周末")
        XCTAssertEqual(RepeatSchedule.custom.rawValue, "自定义星期")
    }
    
    func testCustomRepeatDaysParsing() {
        let state = AppState.shared
        state.customRepeatDays = [2, 3, 4]
        XCTAssertTrue(state.customRepeatDays.contains(2))
        XCTAssertTrue(state.customRepeatDays.contains(3))
        XCTAssertTrue(state.customRepeatDays.contains(4))
        XCTAssertFalse(state.customRepeatDays.contains(1))
    }
    
    // MARK: - AudioDeviceInfo Tests
    
    func testAudioDeviceInfoLabels() {
        let builtIn = AudioDeviceInfo(id: 1, name: "Mac mini 扬声器", isBuiltIn: true, supportsVolumeControl: true)
        XCTAssertTrue(builtIn.label.contains("内置 · 支持平滑渐变"))
        
        let externalSettable = AudioDeviceInfo(id: 2, name: "USB Headset", isBuiltIn: false, supportsVolumeControl: true)
        XCTAssertTrue(externalSettable.label.contains("支持调音"))
        
        let displayPort = AudioDeviceInfo(id: 3, name: "Mi Monitor", isBuiltIn: false, supportsVolumeControl: false)
        XCTAssertTrue(displayPort.label.contains("不支持系统音量调谐"))
    }
    
    // MARK: - PlayerTarget Tests
    
    func testPlayerTargetEnumCases() {
        XCTAssertEqual(PlayerTarget.allCases.count, 4)
        XCTAssertEqual(PlayerTarget.youtubeMusic.rawValue, "YouTube Music")
        XCTAssertEqual(PlayerTarget.appleMusic.rawValue, "Apple Music (系统自带)")
        XCTAssertEqual(PlayerTarget.localFile.rawValue, "自定义本地音频文件")
        XCTAssertEqual(PlayerTarget.fallbackOnly.rawValue, "内置自然和弦唤醒声")
    }
    
    // MARK: - AppState Settings Tests
    
    func testSnoozeDurationSync() {
        let state = AppState.shared
        state.snoozeDurationMinutes = 15
        XCTAssertEqual(state.snoozeDurationMinutes, 15)
        state.snoozeDurationMinutes = 10
        XCTAssertEqual(state.snoozeDurationMinutes, 10)
    }
    
    // MARK: - HolidayManager & Smart Workday Tests
    
    func testHolidayManagerDetection() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone.current
        
        let holidayManager = HolidayManager.shared
        
        // 1. 测试法定节假日识别 (例如 2026-10-01 国庆节)
        if let nationalDay = formatter.date(from: "2026-10-01") {
            let attr = holidayManager.getDayAttribute(for: nationalDay)
            XCTAssertTrue(attr.isStatutoryHoliday, "2026-10-01 应被识别为法定节假日")
            XCTAssertEqual(attr.name, "国庆节")
            XCTAssertEqual(attr.category, .holiday)
            
            // 验证开启智能休假时按休息日处理
            XCTAssertFalse(holidayManager.shouldTreatAsWorkday(date: nationalDay, smartHoliday: true, smartWorkday: true))
            // 验证关闭智能休假时，因 2026-10-01 是周四，按平时自然日判定为工作日
            XCTAssertTrue(holidayManager.shouldTreatAsWorkday(date: nationalDay, smartHoliday: false, smartWorkday: true))
        } else {
            XCTFail("解析 2026-10-01 日期失败")
        }
        
        // 2. 测试调休上班日识别 (例如 2026-10-10 周六，国庆调休上班)
        if let adjustedDay = formatter.date(from: "2026-10-10") {
            let attr = holidayManager.getDayAttribute(for: adjustedDay)
            XCTAssertTrue(attr.isAdjustedWorkday, "2026-10-10 应被识别为调休补班日")
            XCTAssertEqual(attr.name, "国庆调休上班")
            XCTAssertEqual(attr.category, .workday)
            
            // 验证开启智能补班时应作为工作日
            XCTAssertTrue(holidayManager.shouldTreatAsWorkday(date: adjustedDay, smartHoliday: true, smartWorkday: true))
            // 验证关闭智能补班时，作为普通周末休息
            XCTAssertFalse(holidayManager.shouldTreatAsWorkday(date: adjustedDay, smartHoliday: true, smartWorkday: false))
        } else {
            XCTFail("解析 2026-10-10 日期失败")
        }
    }
    
    func testSmartWorkdayRepeatSchedule() {
        let state = AppState.shared
        state.repeatSchedule = .smartWorkday
        XCTAssertEqual(state.repeatSchedule, .smartWorkday)
        
        state.workdayHour = 7
        state.workdayMinute = 30
        state.weekendEnabled = true
        state.weekendHour = 9
        state.weekendMinute = 45
        
        let summary = state.repeatScheduleSummary
        XCTAssertTrue(summary.contains("07:30"))
        XCTAssertTrue(summary.contains("09:45"))
        
        state.weekendEnabled = false
        let summaryClosed = state.repeatScheduleSummary
        XCTAssertTrue(summaryClosed.contains("休"))
    }
}

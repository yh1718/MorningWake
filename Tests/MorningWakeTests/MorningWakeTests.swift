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
}

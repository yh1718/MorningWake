import XCTest
import SwiftUI
import AppKit
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
        
        // 验证 shortTitle 不为空且短小精炼，防止下拉框截断
        for schedule in RepeatSchedule.allCases {
            XCTAssertFalse(schedule.shortTitle.isEmpty)
            XCTAssertLessThanOrEqual(schedule.shortTitle.count, 12, "\(schedule) 的短标题不宜超过12字符")
        }
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
        XCTAssertTrue(displayPort.label.contains("外接输出 · 支持软件音量渐变"))
    }
    
    func testAudioRoutingTargetSelection() {
        let state = AppState.shared
        
        // 测试指定为 Mi Monitor
        state.targetAudioDevice = "Mi Monitor"
        state.forceBuiltInSpeaker = false
        XCTAssertEqual(state.targetAudioDevice, "Mi Monitor")
        XCTAssertFalse(state.forceBuiltInSpeaker)
        
        // 测试软件音量设置
        PlayerController.shared.setSoftwareVolume(0.35)
        XCTAssertEqual(PlayerController.shared.currentSoftwareVolume, 0.35, accuracy: 0.001)
        
        // 重置
        state.targetAudioDevice = ""
    }
    
    func testMiMonitorRoutingAndFadeWithoutIntervention() {
        let originalDevID = AudioEngine.shared.getDefaultOutputDeviceID()
        
        let state = AppState.shared
        state.restorePreviousDevice = true
        state.targetAudioDevice = "Mi Monitor"
        state.forceBuiltInSpeaker = false
        
        // 1. 验证音频路由切换至 Mi Monitor
        state.applyAudioOutputRouting()
        let miMonitorID = AudioEngine.shared.getDeviceID(forName: "Mi Monitor")
        if let targetID = miMonitorID {
            let currentDevID = AudioEngine.shared.getDefaultOutputDeviceID()
            XCTAssertEqual(currentDevID, targetID, "系统输出设备应已成功切换至 Mi Monitor")
        }
        
        // 2. 验证在 Mi Monitor 上的淡入不会被强行切回内置扬声器或触发物理音量干预
        let expectation = expectation(description: "Fade on Mi Monitor completed")
        var interventionTriggered = false
        var progressValues: [Float] = []
        
        AudioEngine.shared.startFade(
            from: 0.2,
            to: 0.8,
            duration: 0.2,
            onProgress: { vol in
                progressValues.append(vol)
            },
            onIntervention: {
                interventionTriggered = true
            },
            onComplete: {
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: 1.5)
        
        XCTAssertFalse(interventionTriggered, "在不可硬件控音的设备上不应误触发物理音量干预")
        XCTAssertFalse(progressValues.isEmpty, "淡入进度回调应正常产生音量更新")
        XCTAssertEqual(AudioEngine.shared.getVolume(), 0.8, accuracy: 0.05, "Mi Monitor 上的当前音量应随渐变平滑增大至目标值 0.8")
        
        if let targetID = miMonitorID {
            let currentDevID = AudioEngine.shared.getDefaultOutputDeviceID()
            XCTAssertEqual(currentDevID, targetID, "淡入过程中不应被劫持切回内置扬声器")
        }
        
        // 3. 验证设备恢复
        state.restoreAudioOutputDeviceIfNeeded()
        let restoredDevID = AudioEngine.shared.getDefaultOutputDeviceID()
        XCTAssertEqual(restoredDevID, originalDevID, "完成或停止后应能无缝还原触发前的原设备")
        
        // 清理状态
        state.targetAudioDevice = ""
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
    
    func testStopAlarmVolumeReduction() {
        let state = AppState.shared
        state.isAlarmRinging = true
        state.currentVolumePercent = 75
        
        // 执行停止/关闭闹钟
        state.stopAlarm()
        
        XCTAssertFalse(state.isAlarmRinging)
        XCTAssertEqual(state.currentVolumePercent, 20, "点击关闭闹钟后，音量应降至 20%")
    }
    
    func testStopTestRunVolumeReduction() {
        let state = AppState.shared
        let originalVol = AudioEngine.shared.getVolume()
        let prevPlayerTarget = state.playerTarget
        
        // 设定已知初始音量并用内置兜底音源启动试跑，验证停止后能准确还原试跑前音量而非强行覆盖为 20%
        AudioEngine.shared.setVolume(0.45)
        state.playerTarget = .fallbackOnly
        state.startTestRun()
        XCTAssertTrue(state.isTestRunning)
        
        state.stopTestRun()
        
        XCTAssertFalse(state.isTestRunning)
        XCTAssertEqual(state.currentVolumePercent, 45, accuracy: 2, "停止试跑后应恢复试跑前记录的原始音量 (45%)")
        
        // 还原环境
        state.playerTarget = prevPlayerTarget
        AudioEngine.shared.setVolume(originalVol)
    }
    
    func testKeepPlayingVolumeFadeTo40() {
        let state = AppState.shared
        state.isAlarmRinging = true
        state.currentVolumePercent = 75
        AudioEngine.shared.setVolume(0.75)
        
        // 执行已醒 (保持播放)
        state.keepPlaying()
        
        XCTAssertFalse(state.isAlarmRinging)
        XCTAssertTrue(state.isManualPlaying, "已醒后应继续保持长效播放模式")
        XCTAssertTrue(AudioEngine.shared.isFading || state.currentVolumePercent == 40, "应触发平缓渐变或置为 40% 音量")
        
        // 清理测试状态
        state.stopManualPlayback()
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
    
    // MARK: - Offline Audio Fallback & Standby Tests
    
    func testAudioRoutingOfflineFallbackToBuiltInSpeaker() {
        let state = AppState.shared
        let originalDevID = AudioEngine.shared.getDefaultOutputDeviceID()
        
        // 模拟目标外接显示器断电离线（设置一个不存在的设备名）
        state.targetAudioDevice = "OfflineDisconnectedMonitor_99999"
        
        // 执行音频路由计算
        let isOnline = state.applyAudioOutputRouting()
        
        // 验证结果：目标离线判定为 false
        XCTAssertFalse(isOnline, "目标设备断电或离线时，applyAudioOutputRouting 应返回 false")
        
        // 验证系统音频设备已安全降级至内置硬件扬声器
        AudioEngine.shared.refreshAudioDevices()
        let currentDevID = AudioEngine.shared.getDefaultOutputDeviceID()
        let currentDev = AudioEngine.shared.availableDevices.first(where: { $0.id == currentDevID })
        XCTAssertNotNil(currentDev, "当前音频设备必须有效存在")
        XCTAssertTrue(currentDev?.isBuiltIn ?? false, "目标设备离线时，系统必须自动安全回退至内置扬声器")
        
        // 还原原设备状态
        if let origID = originalDevID {
            AudioEngine.shared.setDefaultOutputDevice(id: origID)
        }
        state.targetAudioDevice = ""
    }
    
    func testStandbyKeepAliveLifecycle() {
        let state = AppState.shared
        
        // 开启闹钟并排期：应持有 Standby 防冻结保活
        state.isAlarmEnabled = true
        state.reschedule()
        
        // 关闭闹钟：排期被清空，应安全释放保活
        state.isAlarmEnabled = false
        state.reschedule()
        XCTAssertNil(state.nextAlarmDate, "关闭闹钟后下次响铃时间应置空")
        XCTAssertEqual(state.countdownString, "已暂停")
        
        // 恢复开启闹钟
        state.isAlarmEnabled = true
        state.reschedule()
        XCTAssertNotNil(state.nextAlarmDate, "重新开启闹钟后应生成正常排期")
    }
    
    func testPlayerTargetPreservedAndAutoStopDisabled() {
        let state = AppState.shared
        state.playerTarget = .youtubeMusic
        state.targetAudioDevice = "OfflineDisconnectedMonitor_99999"
        
        // 验证自动停播配置为持续播放 (0)
        XCTAssertEqual(state.autoStopDurationMinutes, 0, "自动停播已去除，应为从不停播 (0)")
        
        // 验证默认不再启用强制自带备用音
        XCTAssertFalse(state.fallbackSoundEnabled, "默认不应启用离线备用音")
        
        // 验证用户选定的音源不被覆盖为 fallbackOnly
        XCTAssertEqual(state.playerTarget, .youtubeMusic, "音源应始终尊重用户选择")
        
        state.targetAudioDevice = ""
    }
    
    func testDisplayTargetTimePreservedWhenAlarmDisabled() {
        let state = AppState.shared
        state.repeatSchedule = .smartWorkday
        state.workdayHour = 7
        state.workdayMinute = 45
        
        // 开启闹钟
        state.isAlarmEnabled = true
        state.reschedule()
        XCTAssertEqual(state.displayTargetHour, 7)
        XCTAssertEqual(state.displayTargetMinute, 45)
        
        // 关闭闹钟，时间依然应当稳定返回 07:45，防止 UI 降级为 --:--
        state.isAlarmEnabled = false
        state.reschedule()
        XCTAssertNil(state.nextAlarmDate)
        XCTAssertEqual(state.displayTargetHour, 7, "闹钟关闭时仍应显示设定的工作日小时")
        XCTAssertEqual(state.displayTargetMinute, 45, "闹钟关闭时仍应显示设定的工作日分钟")
        
        // 恢复开启
        state.isAlarmEnabled = true
        state.reschedule()
    }
    
    func testSettingsWindowManagerClose() {
        SettingsWindowManager.shared.showSettings()
        SettingsWindowManager.shared.closeSettings()
        // 验证不会崩溃，正常关闭
        XCTAssertTrue(true)
    }
    
    func testMenuBarViewFittingSizeDoesNotCollapse() {
        let view = MenuBarView()
        let hostingView = SwiftUI.NSHostingView(rootView: view)
        let size = hostingView.fittingSize
        
        // 验证移除根 ScrollView 后，MenuBarView 报告了真实内容尺寸，绝对不会坍塌为 0~25px 窄条卡在顶部
        XCTAssertGreaterThan(size.width, 300, "MenuBarView 宽度应大于 300")
        XCTAssertGreaterThan(size.height, 180, "MenuBarView 固有高度应大于 180，绝对不能因 ScrollView 缺失约束而坍塌到顶部")
    }
    
    func testWindowResizingBridgeAnchorCalculation() {
        // 验证窗口从正常态向编辑态扩展时，顶部锚定不动 (maxY 恒定)，向下扩展
        let initialFrame = NSRect(x: 100, y: 500, width: 360, height: 260)
        let expandedHeight: CGFloat = 310
        let expandedFrame = WindowResizingBridge.calculateTopAnchoredFrame(currentFrame: initialFrame, targetHeight: expandedHeight)
        
        XCTAssertEqual(expandedFrame.maxY, initialFrame.maxY, "顶部 Y 坐标必须严格锁定在菜单栏下方，不可向上突起")
        XCTAssertEqual(expandedFrame.height, expandedHeight, "窗口高度应匹配目标高度")
        XCTAssertEqual(expandedFrame.origin.y, initialFrame.origin.y - (expandedHeight - initialFrame.height), "窗口底部应向下延伸")
        
        // 验证窗口从编辑态收起回正常态时，顶部依然锚定不动，从底部向上收缩
        let collapsedHeight: CGFloat = 260
        let collapsedFrame = WindowResizingBridge.calculateTopAnchoredFrame(currentFrame: expandedFrame, targetHeight: collapsedHeight)
        
        XCTAssertEqual(collapsedFrame.maxY, initialFrame.maxY, "收起时顶部 Y 坐标仍严格锁定")
        XCTAssertEqual(collapsedFrame.height, collapsedHeight, "高度收缩回正常尺寸")
        XCTAssertEqual(collapsedFrame.origin.y, initialFrame.origin.y, "底部坐标恢复原状")
    }
    
    func testFallbackSoundEnabledToggle() {
        let state = AppState.shared
        state.fallbackSoundEnabled = true
        XCTAssertTrue(state.fallbackSoundEnabled)
        state.fallbackSoundEnabled = false
        XCTAssertFalse(state.fallbackSoundEnabled)
    }
    
    func testDisplayTargetTimeSmartScheduleOnRestDay() {
        let state = AppState.shared
        state.repeatSchedule = .smartWorkday
        state.workdayHour = 7
        state.workdayMinute = 30
        state.weekendHour = 9
        state.weekendMinute = 15
        state.weekendEnabled = true
        
        let holidayManager = HolidayManager.shared
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let restDay = formatter.date(from: "2026-10-02") { // 国庆节假期
            let isEffectiveWorkday = holidayManager.shouldTreatAsWorkday(
                date: restDay,
                smartHoliday: state.smartHolidayEnabled,
                smartWorkday: state.smartWorkdayEnabled
            )
            XCTAssertFalse(isEffectiveWorkday, "国庆节假期应被判定为非工作日")
        }
    }
    
    func testHolidayDataAvailabilityForYear() {
        let holidayManager = HolidayManager.shared
        XCTAssertTrue(holidayManager.hasHolidayData(forYear: 2026), "2026 年节假日数据应内置就绪")
        XCTAssertFalse(holidayManager.hasHolidayData(forYear: 2099), "未内置的远期年份应准确返回 false")
    }
    
    // MARK: - Lock Screen Volume Stall vs External Intervention Tests
    
    func testStalledSystemVolumeDoesNotTriggerExternalIntervention() {
        // 模拟锁屏状态下系统音量停滞在 0.25 不动，而目标渐变已推进到 0.40
        let shouldIntervene = AudioEngine.shouldTreatAsExternalIntervention(
            currentSysVol: 0.25,
            lastObservedSysVol: 0.25,
            lastAppliedVolume: 0.40,
            startVol: 0.20,
            targetVol: 0.90,
            lastSetSucceeded: true
        )
        XCTAssertFalse(shouldIntervene, "系统音量停滞在原处未动时，不应误判为外部物理调音干预")
    }
    
    func testFailedSetVolumeDoesNotTriggerExternalIntervention() {
        let shouldIntervene = AudioEngine.shouldTreatAsExternalIntervention(
            currentSysVol: 0.20,
            lastObservedSysVol: 0.25,
            lastAppliedVolume: 0.40,
            startVol: 0.20,
            targetVol: 0.90,
            lastSetSucceeded: false
        )
        XCTAssertFalse(shouldIntervene, "底层音量写入返回失败时，不应误判为外部干预")
    }
    
    func testUserLoweringVolumeTriggersExternalIntervention() {
        // 渐增过程中，用户按物理音量减键把系统音量从 0.35 拉低到 0.25
        let shouldIntervene = AudioEngine.shouldTreatAsExternalIntervention(
            currentSysVol: 0.25,
            lastObservedSysVol: 0.35,
            lastAppliedVolume: 0.36,
            startVol: 0.20,
            targetVol: 0.90,
            lastSetSucceeded: true
        )
        XCTAssertTrue(shouldIntervene, "渐增期间用户主动调低音量应准确触发外部干预")
    }
    
    func testUserBoostingVolumeTriggersExternalIntervention() {
        // 渐增过程中，用户按物理音量加键把系统音量从 0.30 猛拉到 0.55
        let shouldIntervene = AudioEngine.shouldTreatAsExternalIntervention(
            currentSysVol: 0.55,
            lastObservedSysVol: 0.30,
            lastAppliedVolume: 0.31,
            startVol: 0.20,
            targetVol: 0.90,
            lastSetSucceeded: true
        )
        XCTAssertTrue(shouldIntervene, "用户大幅拉高音量应准确触发外部干预")
    }
}

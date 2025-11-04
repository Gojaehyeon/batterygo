import AppKit
import Combine
import IOKit.ps
import SwiftUI
import ServiceManagement

class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var batteryPercentage: Int = BatteryInfo.currentPercentage()
    @Published var isLowPowerMode: Bool = BatteryInfo.isLowPowerModeEnabled()
    @Published var showPercentage: Bool = false
    @Published var powerSource: String = BatteryInfo.powerSource()
    @Published var isCharging: Bool = BatteryInfo.isCharging()
    @Published var fullyCharged: Bool = BatteryInfo.fullyCharged()
    @Published var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        }
    }
    
    init() {
        let saved = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool
        self.launchAtLogin = saved ?? true
        setLaunchAtLogin(self.launchAtLogin)
        createMenuBar()
        startTimer()
    }
    
    private func createMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateButtonTitle()
            button.target = self
        }
        
        createMenu()
    }
    
    private func updateButtonTitle() {
        guard let button = statusItem?.button else { return }
        
        let text = showPercentage ? "\(batteryPercentage)" : "\(batteryPercentage)%"
        
        var textColor: NSColor = .controlTextColor
        
        let isEffectivelyCharging = isCharging || powerSource == (isKoreanLanguage() ? "어댑터" : "Power Adapter")
        
        if !isEffectivelyCharging && batteryPercentage <= 20 {
            textColor = .systemRed
        } else if isLowPowerMode {
            textColor = .systemYellow
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: textColor == .systemRed ? .bold : .regular),
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        button.attributedTitle = attributedString
        
        if powerSource == (isKoreanLanguage() ? "어댑터" : "Power Adapter") {
            // 아이콘 색상 텍스트컬러와 통일
            let iconColor: NSColor
            if !isEffectivelyCharging && batteryPercentage <= 20 {
                iconColor = .systemRed
            } else if isLowPowerMode {
                iconColor = .systemYellow
            } else {
                iconColor = textColor // use textColor, which can be black or white
            }
            
            let symbolName: String
            if isCharging {
                symbolName = "bolt.fill"
            } else if fullyCharged {
                symbolName = "bolt.fill"
            } else {
                symbolName = "bolt"
            }
            
            // 색상이 적용된 아이콘 생성
            let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                .applying(.init(hierarchicalColor: iconColor))
            
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                button.image = image.withSymbolConfiguration(configuration)
            }
            
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
        }
    }

    private func createMenu() {
        let menu = NSMenu()
        
        // 실시간 전력 소모(Watt) 표시
        // if let watt = BatteryInfo.currentWattUsage() {
        //     let wattItem = NSMenuItem(title: String(format: isKoreanLanguage() ? "실시간 전력: %.2f W" : "Current Power: %.2f W", watt), action: nil, keyEquivalent: "")
        //     menu.addItem(wattItem)
        // }
        
        // 충전 시간 정보
        if isCharging {
            let timeToFull = BatteryInfo.timeRemainingUntilFull()
            let timeToFullText = (timeToFull == "계산 중" ? (isKoreanLanguage() ? "계산 중" : "Calculating") : (isKoreanLanguage() ? timeToFull : localizedTimeString(timeToFull)))
            let item = NSMenuItem(title: isKoreanLanguage() ? "충전 완료까지: \(timeToFullText)" : "Time to Full: \(timeToFullText)", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        
        // 사용 시간 정보
        if powerSource == (isKoreanLanguage() ? "배터리" : "Battery") {
            let usageTime = BatteryInfo.estimatedUsageTime()
            let usageTimeText = (usageTime == "계산 중" ? (isKoreanLanguage() ? "계산 중" : "Calculating") : (isKoreanLanguage() ? usageTime : localizedTimeString(usageTime)))
            let item = NSMenuItem(title: isKoreanLanguage() ? "남은 사용 시간: \(usageTimeText)" : "Time Remaining: \(usageTimeText)", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }
        
        // 전원 소스
        let powerSourceItem = NSMenuItem(title: isKoreanLanguage() ? "전원 소스: \(powerSource)" : "Power Source: \(powerSource)", action: nil, keyEquivalent: "")
        menu.addItem(powerSourceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 퍼센트 숨기기 토글
        let toggleItem = NSMenuItem(title: isKoreanLanguage() ? "퍼센트 숨기기" : "Hide Percentage", action: #selector(togglePercentage), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = showPercentage ? .on : .off
        menu.addItem(toggleItem)
        
        // Launch at Login 토글
        let launchAtLoginItem = NSMenuItem(title: isKoreanLanguage() ? "로그인 시 실행" : "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 배터리 설정
        let settingsItem = NSMenuItem(title: isKoreanLanguage() ? "배터리 설정..." : "Battery Settings...", action: #selector(openBatterySettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 종료
        let quitItem = NSMenuItem(title: isKoreanLanguage() ? "종료" : "Quit", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func togglePercentage() {
        showPercentage.toggle()
        updateButtonTitle()
        createMenu() // 메뉴 업데이트
    }
    
    @objc private func openBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        createMenu() // 메뉴 업데이트
    }
    
    private func startTimer() {
        Timer.publish(every: 1, on: .main, in: .common) // 3초 → 1초로 변경 (충전 상태 빠른 감지)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBatteryInfo()
            }
            .store(in: &cancellables)
    }
    
    private func updateBatteryInfo() {
        batteryPercentage = BatteryInfo.currentPercentage()
        isLowPowerMode = BatteryInfo.isLowPowerModeEnabled()
        powerSource = BatteryInfo.powerSource()
        isCharging = BatteryInfo.isCharging()
        fullyCharged = BatteryInfo.fullyCharged()
        
        updateButtonTitle()
        createMenu() // 메뉴 업데이트
    }
    
    private func localizedTimeString(_ str: String) -> String {
        if isKoreanLanguage() { return str }
        return str.replacingOccurrences(of: "시간", with: "h").replacingOccurrences(of: "분", with: "m")
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 14.0, *) {
            if enabled {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
}

// 앱 시작 시 독에서 숨기기 설정
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 모든 윈도우에 대한 기본 탭 모드 비활성화
        NSWindow.allowsAutomaticWindowTabbing = false

        // 실행 중인 앱이 독에 표시되지 않도록 설정
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.tabbingMode = .disallowed
            window.collectionBehavior = [.fullScreenNone]
            window.isExcludedFromWindowsMenu = true
        }
    }
}

// 언어 감지 함수 (전역)
func isKoreanLanguage() -> Bool {
    let systemLanguageCodes = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
    let systemFirstLanguageCode = systemLanguageCodes.first ?? "ko-KR"

    return systemFirstLanguageCode == "ko-KR"
}

@main
struct batteryGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var menuBarController = MenuBarController()
    
    var body: some Scene {
        // 빈 WindowGroup - 실제로는 메뉴바만 사용
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

enum BatteryInfo {
    static func currentPercentage() -> Int {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let percent = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int else { return 0 }
        return Int(Double(percent) / Double(max) * 100)
    }

    static func isLowPowerModeEnabled() -> Bool {
        if #available(macOS 12.0, *) {
            return ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        return false
    }

    static var canControlLowPowerMode: Bool {
        if #available(macOS 12.0, *) {
            return true
        }
        return false
    }

    //    static func setLowPowerMode(enabled: Bool, completion: @escaping (Bool) -> Void) {
    //        if #available(macOS 12.0, *) {
    //            let task = Process()
    //            task.launchPath = "/usr/bin/pmset"
    //            task.arguments = ["-a", "lowpowermode", enabled ? "1" : "0"]
    //            let pipe = Pipe()
    //            task.standardError = pipe
    //            do {
    //                try task.run()
    //                task.waitUntilExit()
    //                let success = (task.terminationStatus == 0)
    //                completion(success)
    //            } catch {
    //                completion(false)
    //            }
    //        } else {
    //            completion(false)
    //        }
    //    }
    static func timeRemainingUntilFull() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let time = description[kIOPSTimeToFullChargeKey as String] as? Int,
              time >= 0
        else {
            return "계산 중"
        }
        let h = time / 60
        let m = time % 60
        let result = h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
    
        return result
    }

    static func estimatedUsageTime() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let time = description[kIOPSTimeToEmptyKey as String] as? Int,
              time >= 0
        else {
            return "계산 중"
        }
        let h = time / 60
        let m = time % 60
        let result = h > 0 ? "\(h)시간 \(m)분" : "\(m)분"
        return result
    }

    static func isCharging() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let isCharging = description[kIOPSIsChargingKey] as? Bool
        else {
            return false
        }
        return isCharging
    }

    static func powerSource() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let ps = description[kIOPSPowerSourceStateKey as String] as? String
        else {
            return "-"
        }
        if ps == kIOPSACPowerValue { return isKoreanLanguage() ? "어댑터" : "Power Adapter" }
        if ps == kIOPSBatteryPowerValue { return isKoreanLanguage() ? "배터리" : "Battery" }
        return ps
    }

    static func batteryCondition() -> String {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let cond = description[kIOPSBatteryHealthKey as String] as? String
        else {
            return "-"
        }
        if isKoreanLanguage() {
            switch cond {
            case "Good": return "정상"
            case "Fair": return "양호"
            case "Poor": return "주의"
            default: return cond
            }
        }
        return cond
    }

    static func fullyCharged() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let charged = description["FullyCharged"] as? Bool
        else {
            return false
        }
        return charged
    }

    static func currentWattUsage() -> Double? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let current = description["Current"] as? Int, // mA
              let voltage = description["Voltage"] as? Int // mV
        else {
            return nil
        }
        return Double(current) * Double(voltage) / 1_000_000.0
    }
}

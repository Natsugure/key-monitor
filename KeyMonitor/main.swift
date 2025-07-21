//
//  main.swift
//  KeyMonitor
//
//  Created by Natsugure on 2025/07/21.
//

import Foundation
import IOKit.hid

class IOHIDKeyMonitor {
    private var manager: IOHIDManager?
    
    init() {
        setupHIDManager()
    }
    
    deinit {
        stop()
    }
    
    private func setupHIDManager() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let manager = manager else {
            print("HIDマネージャーの作成に失敗しました")
            return
        }
        
        // キーボードデバイスのみをフィルタ
        let deviceMatching: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
            ]
        ]
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, deviceMatching as CFArray)
        
        let inputCallback: IOHIDValueCallback = { context, result, sender, value in
            guard let context = context else { return }
            let monitor = Unmanaged<IOHIDKeyMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handleInput(value: value)
        }
        
        IOHIDManagerRegisterInputValueCallback(manager, inputCallback, Unmanaged.passUnretained(self).toOpaque())
        
        // RunLoopにスケジュール
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("HIDマネージャーのオープンに失敗しました: \(openResult)")
            return
        }
        
        print("IOHIDキー監視を開始しました")
        print("終了するには Ctrl+C を押してください\n")
    }
    
    private func handleInput(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)
        
        // 無効な値をフィルタリング
        guard usage != 0xFFFFFFFF && usage != 0 else {
            return
        }
        
        // キーボード関連のUsage Pageのみを処理
        guard usagePage == kHIDPage_KeyboardOrKeypad || usagePage == kHIDPage_Consumer else {
            return
        }
        
        // 有効な範囲のUsage IDのみを処理（キーボードは通常4-231、特殊キーは更に広範囲）
        guard usage >= 4 && usage <= 0xFF else {
            return
        }
        
        // キーの押下/離上イベントのみを処理
        guard integerValue == 0 || integerValue == 1 else {
            return
        }
        
        let timestamp = DateFormatter()
        timestamp.dateFormat = "HH:mm:ss.SSS"
        let timeString = timestamp.string(from: Date())
        
        let state = integerValue == 1 ? "⬇️ DOWN" : "⬆️ UP"
        
        print("[\(timeString)] \(state) | KeyCode: \(usage)")
    }
    
    func start() {
        guard manager != nil else {
            print("Error: HIDマネージャーが初期化されていません")
            return
        }
        
        CFRunLoopRun()
    }
    
    func stop() {
        if let manager = manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }
        print("\n=== IOHIDキー監視を停止しました ===")
    }
}

var hidMonitor: IOHIDKeyMonitor?

func signalHandler(_ signal: Int32) {
    print("\n🔴 終了シグナルを受信しました ===")
    hidMonitor?.stop()
    exit(0)
}

signal(SIGINT, signalHandler)
signal(SIGTERM, signalHandler)

func main() {
    print("=== IOHID Key Monitor for Windows Keyboards ===")
    print("変換・無変換キーの検出を試みます\n")
    
    hidMonitor = IOHIDKeyMonitor()
    hidMonitor?.start()
}

main()

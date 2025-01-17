//
//  Jailbreak.swift
//  Fugu15
//
//  Created by exerhythm on 03.04.2023.
//

import UIKit
import Foundation
import Fugu15KernelExploit
import CBindings

public func rootifyPath(path: String) -> String? {
    var fakeRootPath: String? = nil
    if fakeRootPath == nil {
        fakeRootPath = Bootstrapper.locateExistingFakeRoot()
    }
    if fakeRootPath == nil {
        return nil
    }
    return fakeRootPath! + "/" + path
}

func getBootInfoValue(key: String) -> Any? {
    guard let bootInfoPath = rootifyPath(path: "/var/.boot_info.plist") else {
        return nil
    }
    guard let bootInfo = NSDictionary(contentsOfFile: bootInfoPath) else {
        return nil
    }
    return bootInfo[key]
}

func respring() {
//    guard let sbreloadPath = rootifyPath(path: "/usr/bin/sbreload") else {
//        return
//    }
//    _ = execCmd(args: [sbreloadPath])
    _ = execCmd(args: [rootifyPath(path: "/usr/bin/uicache")!, "-ar"])
}

func userspaceReboot() {
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    
    // MARK: Fade out Animation
    
    let view = UIView(frame: UIScreen.main.bounds)
    view.backgroundColor = .black
    view.alpha = 0

    for window in UIApplication.shared.connectedScenes.map({ $0 as? UIWindowScene }).compactMap({ $0 }).flatMap({ $0.windows.map { $0 } }) {
        window.addSubview(view)
        UIView.animate(withDuration: 0.2, delay: 0, animations: {
            view.alpha = 1
        })
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
        sync();
        _ = execCmd(args: [rootifyPath(path: "/basebin/jbctl")!, "reboot_userspace"])
    })
}

func reboot() {
//    if isJailbroken() {
//        if let paths = try? FileManager.default.contentsOfDirectory(atPath: jbrootPath("/Applications"))
//        {
//            for path in paths {
//                _ = execCmd(args: [rootifyPath(path: "/usr/bin/uicache")!, "-u", "/Applications/\(path)"])
//            }
//        }
//    }
    sync();
    _ = execCmd(args: [CommandLine.arguments[0], "reboot"])
}

func isJailbroken() -> Bool {
    
    if isSandboxed() { return false } // ui debugging
    
    if __isRootlessDopamineJailbroken() {
        return false
    }
    
    var jbdPid: pid_t = 0
    jbdGetStatus(nil, nil, &jbdPid)
    return jbdPid != 0
}

func isRootlessDopamineJailbroken() -> Bool {
    return __isRootlessDopamineJailbroken();
}

func isBootstrapped() -> Bool {
    if isSandboxed() { return false } // ui debugging
    
    return Bootstrapper.isBootstrapped()
}

func jailbreak(completion: @escaping (Error?) -> ()) {
    do {
        handleWifiFixBeforeJailbreak {message in 
            Logger.log(message, isStatus: true)
        }

        Logger.log("Launching kexploitd", isStatus: true)

        try Fugu15.launchKernelExploit(oobPCI: Bundle.main.bundleURL.appendingPathComponent("oobPCI")) { msg in
            DispatchQueue.main.async {
                var toPrint: String
                let verbose = !msg.hasPrefix("Status: ")
                if !verbose {
                    toPrint = String(msg.dropFirst("Status: ".count))
                }
                else {
                    toPrint = msg
                }

                Logger.log(toPrint, isStatus: !verbose)
            }
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        try Fugu15.startEnvironment()
        
        DispatchQueue.main.async {
            Logger.log(NSLocalizedString("Jailbreak_Done", comment: ""), type: .success, isStatus: true)
            completion(nil)
        }
    } catch {
        DispatchQueue.main.async {
            Logger.log("\(error.localizedDescription)", type: .error, isStatus: true)
            completion(error)
            NSLog("Fugu15 error: \(error)")
        }
    }
}

func removeJailbreak() {
    dopamineDefaults().removeObject(forKey: "selectedPackageManagers")
    _ = execCmd(args: [CommandLine.arguments[0], "uninstall_environment"])
    if isJailbroken() {
        reboot()
    }
}

func jailbrokenUpdateTweakInjectionPreference() {
    _ = execCmd(args: [CommandLine.arguments[0], "update_tweak_injection"])
}

func jailbrokenUpdateIDownloadEnabled() {
    let iDownloadEnabled = dopamineDefaults().bool(forKey: "iDownloadEnabled")
    _ = execCmd(args: [rootifyPath(path: "basebin/jbinit")!, iDownloadEnabled ? "start_idownload" : "stop_idownload"])
}

func changeMobilePassword(newPassword: String) {
    guard let dashPath = rootifyPath(path: "/usr/bin/dash") else {
        return;
    }
    //#printf "%s\n" "alpine" | @MEMO_PREFIX@@MEMO_SUB_PREFIX@/sbin/pw usermod root -h 0
    guard let pwPath = rootifyPath(path: "/usr/sbin/pw") else {
        return;
    }
    _ = execCmd(args: [dashPath, "-c", String(format: "printf \"%%s\\n\" \"\(newPassword)\" | \(pwPath) usermod 501 -h 0")])
}

func update(tipaURL: URL) {
    DispatchQueue.global(qos: .userInitiated).async {
        jbdUpdateFromTIPA(tipaURL.path, true)
    }
}

func installedEnvironmentVersion() -> String {
    if isSandboxed() { return "1.0.3" } // ui debugging
    
    return getBootInfoValue(key: "basebin-version") as? String ?? "1.0"
}

func isInstalledEnvironmentVersionMismatching() -> Bool {
    return installedEnvironmentVersion() != Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
}

func updateEnvironment() {
    jbdUpdateFromBasebinTar(Bundle.main.bundlePath + "/basebin.tar", true)
}


// debugging
func isSandboxed() -> Bool {
    !FileManager.default.isWritableFile(atPath: "/var/mobile/")
}

import Foundation
#if os(macOS)
import AppCheck

let firstArg = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/aiterminal-shots"
MainActor.assumeIsolated {
    if firstArg == "--ssh-config-test" {
        print(AppScreenshots.sshConfigTest())
    } else if firstArg == "--portability-test" {
        print(AppScreenshots.portabilityTest())
    } else if firstArg == "--ai-md-test" {
        print(AppScreenshots.aiMarkdownTest())
    } else if firstArg == "--ai-md-all-test" {
        print(AppScreenshots.aiMarkdownAllTest())
    } else if firstArg == "--env-detect-test" {
        print(AppScreenshots.envDetectTest())
    } else if firstArg == "--diag-test" {
        print(AppScreenshots.diagTest())
    } else if firstArg == "--ai-persist-test" {
        print(AppScreenshots.aiPersistTest())
    } else if firstArg == "--ai-conv-test" {
        print(AppScreenshots.aiConvTest())
    } else if firstArg == "--reach-test" {
        // 异步自测：阻塞等待结果
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var out = ""
        Task.detached { out = await AppScreenshots.reachTest(); sem.signal() }
        sem.wait()
        print(out)
    } else {
        AppScreenshots.renderAll(to: firstArg)
    }
}
#endif

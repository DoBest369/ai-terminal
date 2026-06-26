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
    } else if firstArg == "--rollback-test" {
        print(AppScreenshots.rollbackTest())
    } else if firstArg == "--risk-test" {
        print(AppScreenshots.riskTest())
    } else if firstArg == "--template-test" {
        print(AppScreenshots.templateTest())
    } else if firstArg == "--metrics-test" {
        print(AppScreenshots.metricsTest())
    } else if firstArg == "--history-test" {
        print(AppScreenshots.historyTest())
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
    } else if firstArg == "--batch-test" {
        print(AppScreenshots.batchTest())
    } else if firstArg == "--inspect-test" {
        print(AppScreenshots.inspectTest())
    } else {
        AppScreenshots.renderAll(to: firstArg)
    }
}
#endif

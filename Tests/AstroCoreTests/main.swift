import Foundation

var failures = 0
func XCTAssertTrue(_ value: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    if !value() { failures += 1; print("FAIL \(file):\(line): expected true") }
}
func XCTAssertFalse(_ value: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(!value(), file: file, line: line)
}
func XCTAssertEqual<T: Equatable>(_ value: @autoclosure () -> T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    let actual = value()
    if actual != expected { failures += 1; print("FAIL \(file):\(line): \(actual) != \(expected)") }
}
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(value == nil, file: file, line: line)
}
func XCTAssertThrowsError<T>(_ value: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) {
    do { _ = try value(); failures += 1; print("FAIL \(file):\(line): expected error") } catch {}
}

let dictation = DictationTests()
dictation.testStartPreservesDraftAndAppendsPartialResults()
dictation.testEmptyDraftHasNoLeadingSpace()
dictation.testStopThenFinalLeavesEditableDraftAndGoesIdle()
dictation.testEmptyResultRestoresDraftAndReportsNoSpeech()
dictation.testCancelRestoresPreviousDraftAndIgnoresLateResults()
dictation.testLateResultFromPreviousSessionDoesNotTouchNewSession()
dictation.testBlockedWhileTaskRunningOrAlreadyActive()
dictation.testFailureRestoresDraftAndCancelWhenIdleIsHarmless()
dictation.testSessionLimitIsSixtySeconds()
dictation.testBusyWhileListeningOrFinishing()
dictation.testSpanishCandidatesPutSystemLanguagesFirstWithoutDuplicates()
dictation.testPicksFirstSpanishLocaleThatWorksOnDevice()
dictation.testEnglishCandidatesUseOnlyEnglishVariantsAndSystemOnesFirst()
dictation.testDictationLanguageIsSavedByRawValueWithSpanishDefault()

let engines = EngineTests()
try engines.testClaudeConsultIsReadOnlyAndPromptStaysOutOfArguments()
try engines.testClaudeEditAllowsFileEditsButNotArbitraryShell()
try engines.testClaudeAllowsOnlyReadConnectorsAndNoSlashCommands()
try engines.testGeminiModesNeverUseYolo()
engines.testEditStillRejectsBroadAndSensitiveFoldersForEveryEngine()
try engines.testCodexArgumentsAreUnchangedByDefault()
try engines.testEnginePromptDescribesWhatEachEngineCanReach()
engines.testChildEnvironmentOnlyForwardsTheEnginesOwnKeys()
engines.testParsesClaudeStream()
engines.testParsesGeminiStream()

let tests = ProtocolTests()
try tests.testPromptIsNeverPlacedInExecutableArguments()
try tests.testEditModeUsesOnlySelectedWorkspace()
tests.testRejectsEmptyOversizedAndMissingDirectory()
tests.testEditRejectsBroadWorkspaceRoots()
tests.testParsesCommandsOutputMessagesAndErrors()
try tests.testEditRejectsSensitiveDirectoriesAndTheirChildren()
tests.testChildEnvironmentDropsSecretsAndKeepsWhatCodexNeeds()
tests.testStreamingPreservesSplitUTF8AndFinalUnterminatedLine()
try tests.testVaultContextIsLoadedTruncatedAndPassedAsReference()
let processTests = ProcessTests()
try processTests.testStreamsStdoutStderrAndKeepsInputLiteral()
try processTests.testCancellationStopsProcessGroup()
processTests.testMissingExecutableFailsImmediately()
try processTests.testArgumentsAreAcceptedByInstalledCLI()
print(failures == 0 ? "PASS: all checks" : "FAIL: \(failures) assertions")
exit(failures == 0 ? 0 : 1)

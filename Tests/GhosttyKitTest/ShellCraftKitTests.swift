import Foundation
import GhosttyTerminal
@testable import ShellCraftKit
import Testing

struct ShellCraftKitTests {
    @Test
    func styledPromptUsesVisibleColumnWidth() {
        let shell = ShellDefinition(
            prompt: "\u{1B}[38;5;110mcolor\u{1B}[0m > ",
            welcomeMessage: ""
        ) {}

        #expect(shell.promptDisplayWidth == 8)
    }

    @Test
    func terminalDisplayWidthCountsWideCharacters() {
        #expect("abc".terminalDisplayWidth == 3)
        #expect("你好".terminalDisplayWidth == 4)
        #expect("a你b好".terminalDisplayWidth == 6)
        #expect("\u{1B}[31m红色\u{1B}[0m".terminalDisplayWidth == 4)
    }

    @Test
    func cursorColumnUsesDisplayWidthInsteadOfCharacterCount() {
        #expect(
            terminalCursorColumn(
                promptDisplayWidth: 8,
                input: "测试",
                cursorPosition: 2
            ) == 13
        )

        #expect(
            terminalCursorColumn(
                promptDisplayWidth: 8,
                input: "a测b",
                cursorPosition: 2
            ) == 12
        )

        #expect(
            terminalCursorColumn(
                promptDisplayWidth: 8,
                input: "你好吗",
                cursorPosition: 1
            ) == 11
        )
    }

    @Test
    func renderedInputStateTracksWrappedLinesAndCursorPlacement() {
        let state = terminalRenderedInputState(
            promptDisplayWidth: 18,
            input: "hello world",
            cursorPosition: 11,
            terminalColumns: 20
        )

        #expect(state.totalLineCount == 2)
        #expect(state.cursorLineOffset == 1)
        #expect(state.cursorColumn == 10)
    }

    @Test
    func renderedInputStateHandlesPromptOnlyWrapping() {
        let state = terminalRenderedInputState(
            promptDisplayWidth: 18,
            input: "",
            cursorPosition: 0,
            terminalColumns: 10
        )

        #expect(state.totalLineCount == 2)
        #expect(state.cursorLineOffset == 1)
        #expect(state.cursorColumn == 9)
    }

    @Test
    func wrappedTerminalLineCountHandlesExactBoundary() {
        #expect(wrappedTerminalLineCount(displayWidth: 20, terminalColumns: 20) == 1)
        #expect(wrappedTerminalLineCount(displayWidth: 21, terminalColumns: 20) == 2)
    }

    @Test
    func renderedInputStateKeepsCursorOnBoundaryWithoutTrailingContent() {
        let state = terminalRenderedInputState(
            promptDisplayWidth: 18,
            input: "ab",
            cursorPosition: 2,
            terminalColumns: 20
        )

        #expect(state.totalLineCount == 1)
        #expect(state.cursorLineOffset == 0)
        #expect(state.cursorColumn == 20)
    }

    @Test
    func renderedInputStateWrapsBoundaryCursorWhenTrailingContentExists() {
        let state = terminalRenderedInputState(
            promptDisplayWidth: 18,
            input: "abc",
            cursorPosition: 2,
            terminalColumns: 20
        )

        #expect(state.totalLineCount == 2)
        #expect(state.cursorLineOffset == 1)
        #expect(state.cursorColumn == 1)
    }

    @Test
    func incrementalAppendIsAllowedForTailInsertion() {
        #expect(
            canIncrementallyAppendInput(
                previousInput: "hello",
                previousCursorPosition: 5,
                insertedText: " world"
            )
        )
        #expect(
            canIncrementallyAppendInput(
                previousInput: "ni",
                previousCursorPosition: 2,
                insertedText: "你好"
            )
        )
    }

    @Test
    func incrementalAppendFallsBackForMidLineOrControlInput() {
        #expect(
            !canIncrementallyAppendInput(
                previousInput: "hello",
                previousCursorPosition: 2,
                insertedText: "X"
            )
        )
        #expect(
            !canIncrementallyAppendInput(
                previousInput: "hello",
                previousCursorPosition: 5,
                insertedText: "\t"
            )
        )
    }

    @Test
    func sandboxShellSupportsExitAndStyledFallback() {
        let viewport = InMemoryTerminalViewport(
            columns: 80,
            rows: 24,
            widthPixels: 0,
            heightPixels: 0
        )

        switch defaultSandboxShell.processCommand(
            "exit",
            username: "tester",
            terminalSize: viewport
        ) {
        case .exit:
            break

        default:
            Issue.record("expected sandbox shell exit command to terminate the session")
        }

        if case let .output(message) = defaultSandboxShell.processCommand(
            "missing-command",
            username: "tester",
            terminalSize: viewport
        ) {
            #expect(message.contains("\u{1B}["))
            #expect(message.contains("missing-command"))
        } else {
            Issue.record("expected fallback command result to produce output")
        }
    }

    // MARK: - decodeUTF8Incrementally

    @Test
    func utf8IncrementalDecodesCompleteASCII() {
        let (text, leftover) = decodeUTF8Incrementally(Data("hello".utf8))
        #expect(text == "hello")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalDecodesCompleteChinese() {
        let (text, leftover) = decodeUTF8Incrementally(Data("你好".utf8))
        #expect(text == "你好")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalRetainsIncompleteThreeByteSequence() {
        // "你" is E4 BD A0 — send only first 2 bytes
        let partial = Data([0xE4, 0xBD])
        let (text1, leftover1) = decodeUTF8Incrementally(partial)
        #expect(text1 == "")
        #expect(leftover1 == partial)

        // Now complete the sequence
        let full = leftover1 + Data([0xA0])
        let (text2, leftover2) = decodeUTF8Incrementally(full)
        #expect(text2 == "你")
        #expect(leftover2.isEmpty)
    }

    @Test
    func utf8IncrementalRetainsIncompleteFourByteSequence() {
        // 😀 is F0 9F 98 80 — send only first 3 bytes
        let partial = Data([0xF0, 0x9F, 0x98])
        let (text1, leftover1) = decodeUTF8Incrementally(partial)
        #expect(text1 == "")
        #expect(leftover1 == partial)

        let full = leftover1 + Data([0x80])
        let (text2, leftover2) = decodeUTF8Incrementally(full)
        #expect(text2 == "😀")
        #expect(leftover2.isEmpty)
    }

    @Test
    func utf8IncrementalSkipsIllegalLeadByteFF() {
        let (text, leftover) = decodeUTF8Incrementally(Data([0xFF]))
        #expect(text == "")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalSkipsOverlongLeadC0C1() {
        // 0xC0 and 0xC1 are overlong, should be skipped
        let input = Data([0xC0, 0x41, 0xC1, 0x42])
        let (text, leftover) = decodeUTF8Incrementally(input)
        #expect(text == "AB")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalSkipsLeadF5Plus() {
        let input = Data([0xF5, 0x41, 0xF6, 0x42, 0xF7, 0x43])
        let (text, leftover) = decodeUTF8Incrementally(input)
        #expect(text == "ABC")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalSkipsOnlyLeadByteOnInvalidCombination() {
        // 0xE4 expects 2 continuation bytes, but next bytes are ASCII
        let input = Data([0xE4, 0x41, 0x42])
        let (text, leftover) = decodeUTF8Incrementally(input)
        #expect(text == "AB")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalPreservesValidTextAfterIllegalByte() {
        let input = Data([0xFF, 0x68, 0x65, 0x6C, 0x6C, 0x6F])  // 0xFF + "hello"
        let (text, leftover) = decodeUTF8Incrementally(input)
        #expect(text == "hello")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalHandlesEmptyData() {
        let (text, leftover) = decodeUTF8Incrementally(Data())
        #expect(text == "")
        #expect(leftover.isEmpty)
    }

    @Test
    func utf8IncrementalHandlesMixedValidAndIncomplete() {
        // "ab" + incomplete 3-byte lead
        let input = Data([0x61, 0x62, 0xE4, 0xBD])
        let (text, leftover) = decodeUTF8Incrementally(input)
        #expect(text == "ab")
        #expect(leftover == Data([0xE4, 0xBD]))
    }

    @Test
    func utf8IncrementalDecomposedUnicode() {
        // e (0x65) + combining acute accent U+0301 (0xCC 0x81)
        let input = Data([0x65, 0xCC, 0x81])
        let (text, leftover) = decodeUTF8Incrementally(input)
        #expect(text == "e\u{0301}")
        #expect(leftover.isEmpty)
    }
}

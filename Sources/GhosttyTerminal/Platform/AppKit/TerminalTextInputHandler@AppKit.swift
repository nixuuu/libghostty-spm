//
//  TerminalTextInputHandler@AppKit.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit
    import GhosttyKit

    @MainActor
    final class TerminalTextInputHandler: NSObject {
        private weak var view: AppTerminalView?
        private var markedTextState = TerminalMarkedTextState()
        private var accumulatedTexts: [String]?
        private var handledTextCommand = false

        var hasMarkedText: Bool {
            markedTextState.hasMarkedText
        }

        init(view: AppTerminalView) {
            self.view = view
            super.init()
        }

        func startCollectingText() {
            accumulatedTexts = []
            handledTextCommand = false
        }

        func finishCollectingText() -> [String]? {
            defer { accumulatedTexts = nil }
            guard let texts = accumulatedTexts, !texts.isEmpty else { return nil }
            return texts
        }

        func consumeHandledTextCommand() -> Bool {
            defer { handledTextCommand = false }
            return handledTextCommand
        }

        // MARK: - Text Input

        func insertText(_ string: Any) {
            let text: String
            if let attrStr = string as? NSAttributedString {
                text = attrStr.string
            } else if let str = string as? String {
                text = str
            } else {
                return
            }

            markedTextState.clear()
            view?.surface?.preedit("")

            if accumulatedTexts != nil {
                accumulatedTexts?.append(text)
            } else {
                view?.surface?.sendText(text)
            }
        }

        func setMarkedText(
            _ string: Any,
            selectedRange: NSRange
        ) {
            let text: String
            if let attrStr = string as? NSAttributedString {
                text = attrStr.string
            } else if let str = string as? String {
                text = str
            } else {
                return
            }

            markedTextState.setMarkedText(text, selectedRange: selectedRange)

            if text.isEmpty {
                view?.surface?.preedit("")
            } else {
                view?.surface?.preedit(text)
            }
        }

        func unmarkText() {
            markedTextState.clear()
            view?.surface?.preedit("")
        }

        func currentSelectedRange() -> NSRange {
            markedTextState.currentSelectedRange
        }

        func markedRange() -> NSRange {
            markedTextState.markedRange
        }

        func attributedSubstring(
            forProposedRange range: NSRange,
            actualRange: NSRangePointer?
        ) -> NSAttributedString? {
            guard markedTextState.hasMarkedText else {
                actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
                return nil
            }

            let length = markedTextState.documentLength
            let location = min(max(range.location, 0), length)
            let end = min(max(range.location + range.length, location), length)
            let clampedRange = NSRange(location: location, length: end - location)
            actualRange?.pointee = clampedRange

            guard let text = markedTextState.text(in: clampedRange) else {
                return nil
            }
            return NSAttributedString(string: text)
        }

        func handleCommand(_ selector: Selector) {
            guard hasMarkedText else { return }

            switch selector {
            case #selector(NSResponder.deleteBackward(_:)):
                deleteBackward()
            case #selector(NSResponder.cancelOperation(_:)):
                unmarkText()
            default:
                break
            }
        }

        private func deleteBackward() {
            guard markedTextState.deleteBackward() else { return }
            view?.surface?.preedit(markedTextState.text ?? "")
            handledTextCommand = true
        }
    }
#endif

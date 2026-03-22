//
//  AppTerminalView.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit
    import GhosttyKit

    @MainActor
    public final class AppTerminalView: NSView {
        let core = TerminalSurfaceCoordinator()
        var metalLayer: CAMetalLayer?
        var inputHandler: TerminalKeyEventHandler?

        public weak var delegate: (any TerminalSurfaceViewDelegate)? {
            get { core.delegate }
            set { core.delegate = newValue }
        }

        public var controller: TerminalController? {
            get { core.controller }
            set { core.controller = newValue }
        }

        public var configuration: TerminalSurfaceOptions {
            get { core.configuration }
            set { core.configuration = newValue }
        }

        var surface: TerminalSurface? {
            core.surface
        }

        override public init(frame: NSRect) {
            super.init(frame: frame)
            commonInit()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func commonInit() {
            wantsLayer = true

            let metal = CAMetalLayer()
            metal.device = MTLCreateSystemDefaultDevice()
            metal.pixelFormat = .bgra8Unorm
            metal.framebufferOnly = true
            metal.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            metal.isOpaque = false
            metal.backgroundColor = NSColor.clear.cgColor
            layer = metal
            metalLayer = metal
            layer?.backgroundColor = NSColor.clear.cgColor

            inputHandler = TerminalKeyEventHandler(view: self)
            setupTrackingArea()

            core.isAttached = { [weak self] in self?.window != nil }
            core.scaleFactor = { [weak self] in
                Double(
                    self?.window?.backingScaleFactor
                        ?? NSScreen.main?.backingScaleFactor ?? 2.0
                )
            }
            core.viewSize = { [weak self] in
                guard let self else { return (0, 0) }
                return (bounds.width, bounds.height)
            }
            core.platformSetup = { [weak self] config in
                guard let self else { return }
                config.platform_tag = GHOSTTY_PLATFORM_MACOS
                config.platform = ghostty_platform_u(
                    macos: ghostty_platform_macos_s(
                        nsview: Unmanaged.passUnretained(self).toOpaque()
                    )
                )
            }
            core.onMetricsUpdate = { [weak self] in
                self?.updateMetalLayerMetrics()
            }
            core.onPostRender = { [weak self] in
                self?.enforceMetalLayerScale()
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - Raw Key Input

        /// Send a raw key event directly to the terminal surface,
        /// bypassing interpretKeyEvents. Use for special keys (Enter,
        /// Backspace, Tab, Escape) that AppKit routes through doCommand
        /// instead of insertText.
        @discardableResult
        public func sendRawKeyEvent(
            keycode: ghostty_input_key_e,
            action: ghostty_input_action_e,
            mods: ghostty_input_mods_e = ghostty_input_mods_e(rawValue: 0)
        ) -> Bool {
            guard let surface else {
                NSLog("[ghostty] sendRawKeyEvent: surface is nil")
                return false
            }
            var input = ghostty_input_key_s()
            input.action = action
            input.keycode = keycode.rawValue
            input.mods = mods
            input.consumed_mods = ghostty_input_mods_e(rawValue: 0)
            input.composing = false
            input.text = nil
            let result = surface.sendKeyEvent(input)
            NSLog("[ghostty] sendRawKeyEvent: keycode=%d result=%d", keycode.rawValue, result ? 1 : 0)
            return result
        }
    }
#endif

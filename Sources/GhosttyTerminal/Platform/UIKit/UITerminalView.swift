//
//  UITerminalView.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

#if canImport(UIKit)
    import GhosttyKit
    import UIKit

    @MainActor
    public final class UITerminalView: UIView {
        let core = TerminalSurfaceCoordinator()
        var momentumDisplayLink: CADisplayLink?
        var momentumVelocity: CGPoint = .zero
        #if !targetEnvironment(macCatalyst)
            static let minFontSize: Float = 4
            static let maxFontSize: Float = 64
        #endif
        #if targetEnvironment(macCatalyst)
            var activePointerButton: ghostty_input_mouse_button_e?
        #endif
        var hardwareKeyHandled = false
        let touchScrollMultiplier: CGFloat = 3.0
        #if !targetEnvironment(macCatalyst)
            var currentFontSize: Float = 14
            var lastPinchScale: CGFloat = 1.0
        #endif
        lazy var inputHandler = TerminalTextInputHandler(view: self)
        weak var _inputDelegate: (any UITextInputDelegate)?

        #if !targetEnvironment(macCatalyst)
            lazy var terminalInputAccessory = TerminalInputAccessoryView(terminalView: self)
            let stickyModifiers = TerminalStickyModifierState()
            var softwareKeyboardVisible = false
            var pendingKeyboardDismissOnTouchEnd = false
            // Set in touchesBegan when the keyboard is currently down,
            // checked in touchesEnded — defers becomeFirstResponder so
            // a pan-to-scroll gesture (which sets
            // touchDidScrollDuringCurrentTouch=true) won't pop the
            // keyboard mid-scroll.
            var pendingFocusOnTouchEnd = false
            var touchDidScrollDuringCurrentTouch = false
        #endif

        #if !targetEnvironment(macCatalyst)
            public var inputAccessoryStyle: TerminalInputAccessoryStyle {
                get { terminalInputAccessory.style }
                set { terminalInputAccessory.style = newValue }
            }
        #endif

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

        /// Whether the program running in the terminal has asked to
        /// receive mouse events (DECSET 1000/1002/1003).
        ///
        /// A host app uses this to decide who owns a gesture — the local
        /// UI or the remote program. It must not try to infer that from
        /// what it thinks is running: the terminal already knows, and
        /// guessing is how stray SGR sequences end up typed into a shell.
        public var terminalOwnsPointer: Bool {
            surface?.isMouseCaptured ?? false
        }

        /// Report a pointer position, in this view's coordinate space.
        public func sendPointerPosition(_ point: CGPoint) {
            surface?.sendMousePos(x: Double(point.x), y: Double(point.y), mods: GHOSTTY_MODS_NONE)
        }

        /// Report a pointer button press or release. Ghostty decides the
        /// tracking level and the wire encoding; the caller never builds
        /// an escape sequence itself.
        public func sendPointerButton(pressed: Bool, button: ghostty_input_mouse_button_e = GHOSTTY_MOUSE_LEFT) {
            surface?.sendMouseButton(
                state: pressed ? GHOSTTY_MOUSE_PRESS : GHOSTTY_MOUSE_RELEASE,
                button: button,
                mods: GHOSTTY_MODS_NONE
            )
        }

        /// Report a scroll delta.
        public func sendPointerScroll(x: Double, y: Double) {
            surface?.sendMouseScroll(x: x, y: y, mods: ghostty_input_scroll_mods_t())
        }

        var surface: TerminalSurface? {
            core.surface
        }

        public var hasText: Bool {
            true
        }

        override public var canBecomeFirstResponder: Bool {
            true
        }

        override public init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func commonInit() {
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = true
            updateDisplayScale()

            core.isAttached = { [weak self] in self?.window != nil }
            core.scaleFactor = { [weak self] in
                Double(self?.resolvedDisplayScale() ?? UIScreen.main.nativeScale)
            }
            core.viewSize = { [weak self] in
                guard let self else { return (0, 0) }
                return (bounds.width, bounds.height)
            }
            core.platformSetup = { [weak self] config in
                guard let self else { return }
                config.platform_tag = GHOSTTY_PLATFORM_IOS
                config.platform = ghostty_platform_u(
                    ios: ghostty_platform_ios_s(
                        uiview: Unmanaged.passUnretained(self).toOpaque()
                    )
                )
            }
            core.onMetricsUpdate = { [weak self] in
                self?.updateSublayerFrames()
            }
            core.onCellSizeDidChange = { [weak self] in
                self?.refreshTextInputGeometry(reason: "cell-size-action")
            }
            core.onPostRender = { [weak self] in
                self?.enforceSublayerScale()
            }

            setupPlatformInput()
            #if !targetEnvironment(macCatalyst)
                setupKeyboardObservers()
            #endif
        }

        #if !targetEnvironment(macCatalyst)
            func setupKeyboardObservers() {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(keyboardDidShow),
                    name: UIResponder.keyboardDidShowNotification,
                    object: nil
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(keyboardDidHide),
                    name: UIResponder.keyboardDidHideNotification,
                    object: nil
                )
            }

            @objc func keyboardDidShow(_: Notification) {
                guard isFirstResponder else { return }
                softwareKeyboardVisible = true
            }

            @objc func keyboardDidHide(_: Notification) {
                softwareKeyboardVisible = false
            }
        #endif

        func refreshTextInputGeometry(reason: String) {
            guard isFirstResponder || inputHandler.hasMarkedText else { return }
            TerminalDebugLog.log(.ime, "refresh text geometry reason=\(reason)")
            inputHandler.notifyGeometryDidChange(reason: reason)
        }

        func refreshInputAccessoryContent() {
            #if !targetEnvironment(macCatalyst)
                terminalInputAccessory.refreshContent()
            #endif
        }
    }
#endif

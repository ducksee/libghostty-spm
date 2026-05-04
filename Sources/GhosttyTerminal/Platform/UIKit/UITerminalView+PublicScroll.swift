//
//  UITerminalView+PublicScroll.swift
//  libghostty-spm
//
//  Public scroll-by-translation API. Sister to PublicSticky — exists
//  so a host with a custom outer pan recognizer (e.g. one that needs
//  to win over the inner UITextInteraction recognizer when the soft
//  keyboard is up) can drive the same `surface.sendMouseScroll`
//  pipeline that the bundled `setupTouchScrollInput` recognizer uses.
//
//  Why a host needs this:
//  Once `becomeFirstResponder` is called and the soft keyboard is up,
//  iOS attaches a UITextInteraction recognizer to the UITextInput-
//  conforming view (UITerminalView conforms). That recognizer claims
//  vertical pan gestures for cursor scrubbing, which beats the
//  bundled `setupTouchScrollInput` pan in UIKit's gesture priority
//  resolution. Result: the user can't scroll back through scrollback
//  while the keyboard is up. Hosts can install their own outer pan
//  recognizer (configured to win the recognition race), translate
//  finger motion themselves, and forward the delta here — bypassing
//  the textInput hijack entirely.
//
//  Real-device 2026-05-04 user report: "终端键盘弹起后, 上下滑动会
//  触发输入而不是滚动看历史, swift 版正常". Without this surface,
//  the host's only options are:
//    * temporarily resignFirstResponder during pan (kills IME state),
//    * or send synthesized arrow-key bytes (works in less / vim only,
//      not in raw shells).
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    import Foundation
    import UIKit

    @MainActor
    public extension UITerminalView {
        /// Programmatically scroll the terminal viewport by a CGPoint
        /// delta in points. Positive y = scroll down (newer content);
        /// negative y = scroll up (older content / scrollback). x is
        /// usually zero on touch input.
        ///
        /// Internally calls the same `surface.sendMouseScroll` path the
        /// bundled touch-pan recognizer uses, so behavior is identical
        /// (precision flag set, momentum semantics inherited from
        /// libghostty's own scrollback handling).
        ///
        /// Safe to call from any thread but expects MainActor.
        ///
        /// No-op if the surface isn't attached yet (early lifecycle
        /// before the first surface_init).
        func forceMouseScroll(translation: CGPoint) {
            let mods = TerminalScrollModifiers(precision: true)
            surface?.sendMouseScroll(
                x: Double(translation.x * touchScrollMultiplier),
                y: Double(translation.y * touchScrollMultiplier),
                mods: mods.rawValue
            )
        }
    }
#endif

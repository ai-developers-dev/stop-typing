//
//  StopTypingPopoverView.swift
//  wispr
//
//  Bold popover panel with Obsidian Flux branding:
//  centered header, full-width CTA, card-grouped rows,
//  generous spacing inspired by modern panel UIs.
//

import SwiftUI

/// Actions the popover view can trigger, forwarded to MenuBarController.
@MainActor
struct PopoverActions {
    var toggleRecording: () -> Void = {}
    var openSettings: () -> Void = {}
    var openModelManagement: () -> Void = {}
    var selectAutoDetect: () -> Void = {}
    var selectLanguage: (String) -> Void = { _ in }
    var openUpdateDownload: () -> Void = {}
    var showCLIInstallDialog: () -> Void = {}
    var quitApp: () -> Void = {}
    var dismiss: () -> Void = {}
}

/// Full menu panel hosted inside the NSPopover.
struct StopTypingPopoverView: View {
    @Environment(UIThemeEngine.self) private var themeEngine: UIThemeEngine

    let appState: AppStateType
    let languageMode: TranscriptionLanguage
    let hotkeyDisplayString: String
    let availableUpdate: AppUpdateInfo?
    let isCLIInstalled: Bool
    let actions: PopoverActions

    @State private var isLanguageExpanded = false

    private var hc: Bool { themeEngine.increaseContrast }

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            gradientRule
            recordingCTA
            cardSpacer
            languageCard
            cardSpacer
            settingsCard
            conditionalCards
            quitSection
            versionFooter
        }
        .padding(20)
        .frame(width: 400)
        .background(StopTypingBrand.swiftCanvas)
    }

    // MARK: - Brand Header (centered, bold)

    private var brandHeader: some View {
        VStack(spacing: 6) {
            Text("ST")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(hc ? .primary : StopTypingBrand.swiftOnSurface)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(StopTypingBrand.swiftSurfaceContainer)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    hc ? .primary.opacity(0.5) : StopTypingBrand.swiftPrimary.opacity(0.35),
                                    lineWidth: 1
                                )
                        )
                )

            Text("Stop Typing")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(hc ? .primary : StopTypingBrand.swiftOnSurface)

            Text("Voice Dictation")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hc ? .secondary : StopTypingBrand.swiftPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    private var gradientRule: some View {
        LinearGradient(
            colors: hc
                ? [.primary.opacity(0.3), .primary.opacity(0.1)]
                : [StopTypingBrand.swiftPrimary, StopTypingBrand.swiftPrimaryContainer.opacity(0.3)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 2)
        .padding(.bottom, 16)
    }

    // MARK: - Recording CTA Button

    private var recordingCTA: some View {
        let isRecording = appState == .recording
        let title = isRecording ? "Stop Recording" : "Start Recording"
        let symbol = isRecording ? SFSymbols.menuBarRecording : SFSymbols.menuBarIdle
        let accent = isRecording
            ? (hc ? .primary : StopTypingBrand.swiftSecondary)
            : (hc ? .primary : StopTypingBrand.swiftPrimary)

        return Button {
            actions.toggleRecording()
            actions.dismiss()
        } label: {
            HStack(spacing: 12) {
                RecordingIconView(
                    symbol: symbol,
                    accent: accent,
                    isRecording: isRecording,
                    reduceMotion: themeEngine.reduceMotion
                )

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)

                Spacer()

                Text(hotkeyDisplayString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accent.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isRecording
                            ? (hc ? Color.primary.opacity(0.08) : StopTypingBrand.swiftSecondary.opacity(0.12))
                            : StopTypingBrand.swiftSurfaceContainer
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(accent.opacity(0.2), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(appState == .processing)
        .opacity(appState == .processing ? 0.35 : 1)
        .accessibilityLabel("\(title), \(hotkeyDisplayString)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Card Groups

    private var languageCard: some View {
        CardGroup {
            VStack(spacing: 0) {
                CardRow(
                    symbol: SFSymbols.language,
                    title: languageDisplayTitle,
                    accent: hc ? .primary : StopTypingBrand.swiftPrimary,
                    textColor: hc ? .primary : StopTypingBrand.swiftOnSurface,
                    chevron: isLanguageExpanded ? .up : .down
                ) {
                    isLanguageExpanded.toggle()
                }

                if isLanguageExpanded {
                    cardDivider
                    languageList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(themeEngine.reduceMotion ? nil : .easeOut(duration: 0.15), value: isLanguageExpanded)
        }
    }

    private var settingsCard: some View {
        CardGroup {
            VStack(spacing: 0) {
                CardRow(
                    symbol: SFSymbols.settings,
                    title: "Settings\u{2026}",
                    trailing: "\u{2318},",
                    accent: hc ? .primary : StopTypingBrand.swiftPrimary,
                    textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
                ) {
                    actions.openSettings()
                    actions.dismiss()
                }

                cardDivider

                CardRow(
                    symbol: SFSymbols.model,
                    title: "Model Management\u{2026}",
                    accent: hc ? .primary : StopTypingBrand.swiftPrimary,
                    textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
                ) {
                    actions.openModelManagement()
                    actions.dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var conditionalCards: some View {
        if let update = availableUpdate {
            cardSpacer
            CardGroup {
                CardRow(
                    symbol: SFSymbols.download,
                    title: "Update Available: \(update.version)",
                    accent: hc ? .primary : StopTypingBrand.swiftPrimaryContainer,
                    textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
                ) {
                    actions.openUpdateDownload()
                    actions.dismiss()
                }
            }
        }

        if !isCLIInstalled {
            cardSpacer
            CardGroup {
                CardRow(
                    symbol: SFSymbols.terminal,
                    title: "Install Command Line Tool\u{2026}",
                    accent: hc ? .primary : StopTypingBrand.swiftPrimary,
                    textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
                ) {
                    actions.showCLIInstallDialog()
                    actions.dismiss()
                }
            }
        }
    }

    // MARK: - Quit & Footer

    private var quitSection: some View {
        Button {
            actions.quitApp()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: SFSymbols.quit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(StopTypingBrand.swiftOnSurfaceVariant)

                Text("Quit Stop Typing")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(StopTypingBrand.swiftOnSurfaceVariant)

                Spacer()

                Text("\u{2318}Q")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(StopTypingBrand.swiftOnSurfaceVariant.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
        .accessibilityLabel("Quit Stop Typing, Command Q")
        .accessibilityAddTraits(.isButton)
    }

    private var versionFooter: some View {
        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(
                hc ? .secondary.opacity(0.5) : StopTypingBrand.swiftPrimary.opacity(0.35)
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
    }

    // MARK: - Language List

    private var languageDisplayTitle: String {
        switch languageMode {
        case .autoDetect:
            return "Language: Auto-Detect"
        case .specific(let code):
            return "Language: \(languageDisplayName(for: code))"
        case .pinned(let code):
            return "Language: \(languageDisplayName(for: code)) (Pinned)"
        }
    }

    private func languageDisplayName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    private var languageList: some View {
        VStack(spacing: 0) {
            languageItem(title: "Auto-Detect", isSelected: languageMode.isAutoDetect) {
                actions.selectAutoDetect()
            }
            ForEach(SupportedLanguage.all) { lang in
                languageItem(
                    title: lang.name,
                    isSelected: languageMode.languageCode == lang.id
                ) {
                    actions.selectLanguage(lang.id)
                }
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 4)
    }

    private func languageItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        CardRow(
            symbol: isSelected ? SFSymbols.checkmarkPlain : nil,
            title: title,
            accent: hc ? .primary : StopTypingBrand.swiftPrimary,
            textColor: hc ? .primary : StopTypingBrand.swiftOnSurface,
            compact: true
        ) {
            action()
        }
    }

    // MARK: - Helpers

    private var cardSpacer: some View {
        Spacer().frame(height: 12)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(StopTypingBrand.swiftSurfaceContainerHigh.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 12)
    }
}

// MARK: - CardGroup

/// A rounded dark container that groups related rows.
private struct CardGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(StopTypingBrand.swiftSurfaceContainerLow)
            )
    }
}

// MARK: - CardRow

/// A single interactive row inside a card group.
private struct CardRow: View {
    let symbol: String?
    let title: String
    var trailing: String? = nil
    let accent: Color
    var textColor: Color
    var chevron: ChevronDirection? = nil
    var compact: Bool = false
    let action: () -> Void

    enum ChevronDirection {
        case up, down
    }

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 13 : 18, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 24, alignment: .center)
                } else if !compact {
                    Spacer().frame(width: 24)
                }

                Text(title)
                    .font(.system(size: compact ? 13 : 15, weight: compact ? .medium : .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Spacer()

                if let chevron {
                    Image(systemName: chevron == .up ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent.opacity(0.5))
                }

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(accent.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: compact ? 32 : 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isHovered
                ? StopTypingBrand.swiftSurfaceContainerHigh.opacity(0.6)
                : Color.clear
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(trailing.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - RecordingIconView

/// Animated mic icon with pulsing glow ring for the CTA button.
private struct RecordingIconView: View {
    let symbol: String
    let accent: Color
    let isRecording: Bool
    let reduceMotion: Bool

    @State private var glowPulse = false

    var body: some View {
        ZStack {
            if isRecording && !reduceMotion {
                Circle()
                    .fill(accent.opacity(glowPulse ? 0.3 : 0.08))
                    .frame(width: 36, height: 36)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: glowPulse
                    )
            }
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 28, alignment: .center)
        .onAppear {
            if isRecording { glowPulse = true }
        }
        .onChange(of: isRecording) { _, recording in
            glowPulse = recording
        }
    }
}

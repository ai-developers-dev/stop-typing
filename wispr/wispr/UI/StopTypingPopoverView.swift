//
//  StopTypingPopoverView.swift
//  wispr
//
//  Phase 3 popover panel with full Obsidian Flux branding:
//  prominent "Stop Typing" header, larger rows, teal accents,
//  recording glow, and version footer.
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
            recordingRow
            divider
            languageSection
            divider
            settingsRow
            modelManagementRow

            if let update = availableUpdate {
                divider
                updateRow(update)
            }

            if !isCLIInstalled {
                divider
                cliInstallRow
            }

            divider
            quitRow
            versionFooter
        }
        .padding(.vertical, 8)
        .frame(width: 340)
        .background(StopTypingBrand.swiftCanvas)
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        HStack(spacing: 10) {
            Text("ST")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    hc ? .primary : StopTypingBrand.swiftOnSurface
                )
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StopTypingBrand.swiftSurfaceContainer)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    hc ? .primary.opacity(0.5) : StopTypingBrand.swiftPrimary.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                )

            VStack(alignment: .leading, spacing: 1) {
                Text("Stop Typing")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(hc ? .primary : StopTypingBrand.swiftOnSurface)
                Text("Voice Dictation")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(hc ? .secondary : StopTypingBrand.swiftPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
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
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Rows

    private var recordingRow: some View {
        let isRecording = appState == .recording
        let title = isRecording ? "Stop Recording" : "Start Recording"
        let symbol = isRecording ? SFSymbols.menuBarRecording : SFSymbols.menuBarIdle
        let accent = isRecording
            ? (hc ? .primary : StopTypingBrand.swiftSecondary)
            : (hc ? .primary : StopTypingBrand.swiftPrimary)

        return PopoverMenuRow(
            symbol: symbol,
            title: title,
            trailing: hotkeyDisplayString,
            accent: accent,
            textColor: accent,
            isDisabled: appState == .processing,
            isRecording: isRecording,
            reduceMotion: themeEngine.reduceMotion
        ) {
            actions.toggleRecording()
            actions.dismiss()
        }
    }

    private var settingsRow: some View {
        PopoverMenuRow(
            symbol: SFSymbols.settings,
            title: "Settings\u{2026}",
            trailing: "\u{2318},",
            accent: hc ? .primary : StopTypingBrand.swiftPrimary,
            textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
        ) {
            actions.openSettings()
            actions.dismiss()
        }
    }

    private var modelManagementRow: some View {
        PopoverMenuRow(
            symbol: SFSymbols.model,
            title: "Model Management\u{2026}",
            accent: hc ? .primary : StopTypingBrand.swiftPrimary,
            textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
        ) {
            actions.openModelManagement()
            actions.dismiss()
        }
    }

    private func updateRow(_ update: AppUpdateInfo) -> some View {
        PopoverMenuRow(
            symbol: SFSymbols.download,
            title: "Update Available: \(update.version)",
            accent: hc ? .primary : StopTypingBrand.swiftPrimaryContainer,
            textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
        ) {
            actions.openUpdateDownload()
            actions.dismiss()
        }
    }

    private var cliInstallRow: some View {
        PopoverMenuRow(
            symbol: SFSymbols.terminal,
            title: "Install Command Line Tool\u{2026}",
            accent: hc ? .primary : StopTypingBrand.swiftPrimary,
            textColor: hc ? .primary : StopTypingBrand.swiftOnSurface
        ) {
            actions.showCLIInstallDialog()
            actions.dismiss()
        }
    }

    private var quitRow: some View {
        PopoverMenuRow(
            symbol: SFSymbols.quit,
            title: "Quit Stop Typing",
            trailing: "\u{2318}Q",
            accent: hc ? .secondary : StopTypingBrand.swiftSecondary,
            textColor: hc ? .secondary : StopTypingBrand.swiftSecondary
        ) {
            actions.quitApp()
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        VStack(spacing: 0) {
            languageHeaderRow
            if isLanguageExpanded {
                languageList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(themeEngine.reduceMotion ? nil : .easeOut(duration: 0.15), value: isLanguageExpanded)
    }

    private var languageHeaderRow: some View {
        PopoverMenuRow(
            symbol: SFSymbols.language,
            title: languageDisplayTitle,
            trailing: nil,
            accent: hc ? .primary : StopTypingBrand.swiftPrimary,
            textColor: hc ? .primary : StopTypingBrand.swiftOnSurface,
            chevron: isLanguageExpanded ? .up : .down
        ) {
            isLanguageExpanded.toggle()
        }
    }

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
        .padding(.leading, 30)
    }

    private func languageItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        PopoverMenuRow(
            symbol: isSelected ? SFSymbols.checkmarkPlain : nil,
            title: title,
            accent: hc ? .primary : StopTypingBrand.swiftPrimary,
            textColor: hc ? .primary : StopTypingBrand.swiftOnSurface,
            compact: true
        ) {
            action()
        }
    }

    // MARK: - Divider & Footer

    private var divider: some View {
        Rectangle()
            .fill(
                hc
                    ? .primary.opacity(0.15)
                    : StopTypingBrand.swiftPrimary.opacity(0.10)
            )
            .frame(height: 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }

    private var versionFooter: some View {
        HStack {
            Spacer()
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(
                    hc ? .secondary.opacity(0.5) : StopTypingBrand.swiftPrimary.opacity(0.35)
                )
            Spacer()
        }
        .padding(.top, 2)
        .padding(.bottom, 2)
    }
}

// MARK: - PopoverMenuRow

/// A single interactive row in the popover menu.
private struct PopoverMenuRow: View {
    let symbol: String?
    let title: String
    var trailing: String? = nil
    let accent: Color
    var textColor: Color
    var isDisabled: Bool = false
    var isRecording: Bool = false
    var reduceMotion: Bool = false
    var chevron: ChevronDirection? = nil
    var compact: Bool = false
    let action: () -> Void

    enum ChevronDirection {
        case up, down
    }

    @State private var isHovered = false
    @State private var glowPulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol {
                    ZStack {
                        if isRecording && !reduceMotion {
                            Circle()
                                .fill(accent.opacity(glowPulse ? 0.25 : 0.08))
                                .frame(width: 28, height: 28)
                                .animation(
                                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                    value: glowPulse
                                )
                        }
                        Image(systemName: symbol)
                            .font(.system(size: compact ? 12 : 15, weight: .medium))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 22, alignment: .center)
                } else if !compact {
                    Spacer().frame(width: 22)
                }

                Text(title)
                    .font(.system(size: compact ? 12 : 14, weight: .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Spacer()

                if let chevron {
                    Image(systemName: chevron == .up ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accent.opacity(0.6))
                }

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(accent.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: isRecording ? 40 : (compact ? 26 : 34))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovered
                        ? accent.opacity(0.10)
                        : Color.clear
                )
                .padding(.horizontal, 8)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            if isRecording { glowPulse = true }
        }
        .onChange(of: isRecording) { _, recording in
            glowPulse = recording
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .accessibilityLabel(trailing.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isButton)
    }
}

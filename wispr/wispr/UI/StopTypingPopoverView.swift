//
//  StopTypingPopoverView.swift
//  wispr
//
//  Phase 3: SwiftUI popover panel replacing the NSMenu dropdown.
//  Provides full visual control over background, row styling,
//  and animations using the Stitch / Obsidian Flux design tokens.
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

    private var useHighContrast: Bool { themeEngine.increaseContrast }

    private var brandPrimary: Color {
        useHighContrast ? .primary : Color(nsColor: StopTypingBrand.primary)
    }
    private var brandSecondary: Color {
        useHighContrast ? .primary : Color(nsColor: StopTypingBrand.secondary)
    }
    private var brandOnSurface: Color {
        useHighContrast ? .primary : Color(nsColor: StopTypingBrand.onSurface)
    }
    private var brandCanvas: Color {
        Color(nsColor: StopTypingBrand.canvas)
    }
    private var brandPrimaryContainer: Color {
        useHighContrast ? .primary : Color(nsColor: StopTypingBrand.primaryContainer)
    }

    var body: some View {
        VStack(spacing: 0) {
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
        }
        .padding(.vertical, 6)
        .frame(width: 280)
        .background(brandCanvas)
    }

    // MARK: - Rows

    private var recordingRow: some View {
        let isRecording = appState == .recording
        let title = isRecording ? "Stop Recording" : "Start Recording"
        let symbol = isRecording ? SFSymbols.menuBarRecording : SFSymbols.menuBarIdle
        let accent = isRecording ? brandSecondary : brandPrimary

        return PopoverMenuRow(
            symbol: symbol,
            title: title,
            trailing: hotkeyDisplayString,
            accent: accent,
            textColor: accent,
            isDisabled: appState == .processing
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
            accent: brandPrimary,
            textColor: brandOnSurface
        ) {
            actions.openSettings()
            actions.dismiss()
        }
    }

    private var modelManagementRow: some View {
        PopoverMenuRow(
            symbol: SFSymbols.model,
            title: "Model Management\u{2026}",
            accent: brandPrimary,
            textColor: brandOnSurface
        ) {
            actions.openModelManagement()
            actions.dismiss()
        }
    }

    private func updateRow(_ update: AppUpdateInfo) -> some View {
        PopoverMenuRow(
            symbol: SFSymbols.download,
            title: "Update Available: \(update.version)",
            accent: brandPrimaryContainer,
            textColor: brandOnSurface
        ) {
            actions.openUpdateDownload()
            actions.dismiss()
        }
    }

    private var cliInstallRow: some View {
        PopoverMenuRow(
            symbol: SFSymbols.terminal,
            title: "Install Command Line Tool\u{2026}",
            accent: brandPrimary,
            textColor: brandOnSurface
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
            accent: useHighContrast ? .secondary : Color(nsColor: StopTypingBrand.secondary),
            textColor: useHighContrast ? .secondary : Color(nsColor: StopTypingBrand.secondary)
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
            accent: brandPrimary,
            textColor: brandOnSurface,
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
        .padding(.leading, 28)
    }

    private func languageItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        PopoverMenuRow(
            symbol: isSelected ? SFSymbols.checkmarkPlain : nil,
            title: title,
            accent: brandPrimary,
            textColor: brandOnSurface,
            compact: true
        ) {
            action()
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(brandPrimary.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
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
    var chevron: ChevronDirection? = nil
    var compact: Bool = false
    let action: () -> Void

    enum ChevronDirection {
        case up, down
    }

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: compact ? 11 : 13, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 18, alignment: .center)
                } else if !compact {
                    Spacer().frame(width: 18)
                }

                Text(title)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Spacer()

                if let chevron {
                    Image(systemName: chevron == .up ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accent.opacity(0.7))
                }

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(accent.opacity(0.9))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: compact ? 24 : 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? accent.opacity(0.1) : Color.clear)
                .padding(.horizontal, 6)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .accessibilityLabel(trailing.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(.isButton)
    }
}

//
//  StopTypingPopoverView.swift
//  wispr
//
//  Bold popover panel with Obsidian Flux branding:
//  centered header, live status card, mic selector,
//  card-grouped rows, generous spacing.
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
    var selectAudioDevice: (AudioInputDevice) -> Void = { _ in }
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
    let activeModelName: String
    let audioDevices: [AudioInputDevice]
    let selectedDeviceUID: String?
    let availableUpdate: AppUpdateInfo?
    let isCLIInstalled: Bool
    let actions: PopoverActions

    @State private var isLanguageExpanded = false
    @State private var isMicExpanded = false

    private var hc: Bool { themeEngine.increaseContrast }

    private var selectedDeviceName: String {
        if let uid = selectedDeviceUID,
           let device = audioDevices.first(where: { $0.uid == uid }) {
            return device.name
        }
        return audioDevices.first?.name ?? "System Default"
    }

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            gradientRule
            statusCard
            cardSpacer
            micCard
            cardSpacer
            languageCard
            cardSpacer
            settingsCard

            if let update = availableUpdate {
                cardSpacer
                updateCard(update)
            }

            quitSection
            versionFooter
        }
        .padding(28)
        .frame(width: 500)
        .background(StopTypingBrand.swiftCanvas)
    }

    // MARK: - Brand Header (centered, bold)

    private var brandHeader: some View {
        VStack(spacing: 10) {
            Text("ST")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(hc ? .primary : StopTypingBrand.swiftOnSurface)
                .frame(width: 64, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(StopTypingBrand.swiftSurfaceContainer)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    hc ? .primary.opacity(0.5) : StopTypingBrand.swiftPrimary.opacity(0.35),
                                    lineWidth: 1
                                )
                        )
                )

            Text("Stop Typing")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(hc ? .primary : StopTypingBrand.swiftOnSurface)

            Text("Voice Dictation")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(hc ? .secondary : StopTypingBrand.swiftPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 22)
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
        .padding(.bottom, 18)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        CardGroup {
            VStack(spacing: 0) {
                StatusRow(
                    label: "Status",
                    value: statusDisplayText,
                    dotColor: statusDotColor,
                    hc: hc
                )
                cardDivider
                StatusRow(label: "Model", value: activeModelName, hc: hc)
                cardDivider
                StatusRow(label: "Shortcut", value: hotkeyDisplayString, hc: hc)
            }
            .padding(.vertical, 6)
        }
    }

    private var statusDisplayText: String {
        switch appState {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .processing: return "Processing..."
        case .loading: return "Loading..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var statusDotColor: Color {
        switch appState {
        case .idle: return hc ? .green : StopTypingBrand.swiftPrimary
        case .recording: return hc ? .cyan : StopTypingBrand.swiftSecondary
        case .processing: return .orange
        case .loading: return .yellow
        case .error: return .red
        }
    }

    // MARK: - Microphone Card

    private var micCard: some View {
        CardGroup {
            VStack(spacing: 0) {
                CardRow(
                    symbol: "mic.fill",
                    title: "Microphone: \(selectedDeviceName)",
                    accent: hc ? .primary : StopTypingBrand.swiftPrimary,
                    textColor: hc ? .primary : StopTypingBrand.swiftOnSurface,
                    chevron: isMicExpanded ? .up : .down
                ) {
                    isMicExpanded.toggle()
                }

                if isMicExpanded {
                    cardDivider
                    micList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(themeEngine.reduceMotion ? nil : .easeOut(duration: 0.15), value: isMicExpanded)
        }
    }

    private var micList: some View {
        VStack(spacing: 0) {
            ForEach(audioDevices) { device in
                let isSelected = device.uid == selectedDeviceUID
                    || (selectedDeviceUID == nil && device == audioDevices.first)
                CardRow(
                    symbol: isSelected ? SFSymbols.checkmarkPlain : nil,
                    title: device.name,
                    accent: hc ? .primary : StopTypingBrand.swiftPrimary,
                    textColor: hc ? .primary : StopTypingBrand.swiftOnSurface,
                    compact: true
                ) {
                    actions.selectAudioDevice(device)
                }
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 4)
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

    private func updateCard(_ update: AppUpdateInfo) -> some View {
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

    // MARK: - Quit & Footer

    private var quitSection: some View {
        Button {
            actions.quitApp()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: SFSymbols.quit)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(StopTypingBrand.swiftOnSurfaceVariant)

                Text("Quit Stop Typing")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(StopTypingBrand.swiftOnSurfaceVariant)

                Spacer()

                Text("\u{2318}Q")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(StopTypingBrand.swiftOnSurfaceVariant.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 18)
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
            .padding(.top, 14)
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
        Spacer().frame(height: 14)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(StopTypingBrand.swiftSurfaceContainerHigh.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 12)
    }
}

// MARK: - CardGroup

private struct CardGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(StopTypingBrand.swiftSurfaceContainerLow)
            )
    }
}

// MARK: - StatusRow

private struct StatusRow: View {
    let label: String
    let value: String
    var dotColor: Color? = nil
    var hc: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(StopTypingBrand.swiftOnSurfaceVariant)
                .frame(width: 80, alignment: .leading)

            Spacer()

            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
            }

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(hc ? .primary : StopTypingBrand.swiftOnSurface)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .frame(height: 38)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - CardRow

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
                        .font(.system(size: compact ? 14 : 18, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 26, alignment: .center)
                } else if !compact {
                    Spacer().frame(width: 26)
                }

                Text(title)
                    .font(.system(size: compact ? 14 : 16, weight: compact ? .medium : .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Spacer()

                if let chevron {
                    Image(systemName: chevron == .up ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accent.opacity(0.5))
                }

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(accent.opacity(0.6))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: compact ? 34 : 48)
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

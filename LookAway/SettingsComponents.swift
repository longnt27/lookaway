import SwiftUI

enum SettingsLayout {
    static let pageWidth: CGFloat = 520
    static let labelWidth: CGFloat = 170
    static let columnGap: CGFloat = 12
    static let pickerWidth: CGFloat = 210
    static let textWidth: CGFloat = 280
    static let numberWidth: CGFloat = 64
    static let unitWidth: CGFloat = 34
    static let pagePadding: CGFloat = 18
    static let sectionGap: CGFloat = 14
    static let rowGap: CGFloat = 8
    static let cardPadding: CGFloat = 12
}

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsLayout.columnGap) {
            Text(label)
                .lineLimit(1)
                .frame(width: SettingsLayout.labelWidth, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: SettingsLayout.pageWidth, alignment: .leading)
    }
}

struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    var body: some View {
        SettingsRow(label) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(label)
        }
    }
}

struct SettingsNumericRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    init(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) {
        self.label = label
        self._value = value
        self.range = range
        self.unit = unit
    }

    private var bounded: Binding<Int> {
        Binding(
            get: { min(max(value, range.lowerBound), range.upperBound) },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    var body: some View {
        SettingsRow(label) {
            HStack(spacing: 8) {
                TextField(label, value: bounded, format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: SettingsLayout.numberWidth)
                    .accessibilityLabel(label)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: SettingsLayout.unitWidth, alignment: .leading)
                Stepper(value: bounded, in: range) { EmptyView() }
                    .labelsHidden()
                    .fixedSize()
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct SettingsTextRow: View {
    let label: String
    @Binding var text: String
    var maxLength = 120
    var width = SettingsLayout.textWidth

    var body: some View {
        SettingsRow(label) {
            TextField(
                label,
                text: Binding(
                    get: { text },
                    set: { text = String($0.prefix(maxLength)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .accessibilityLabel(label)
        }
    }
}

struct SettingsPickerRow<Value: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: Value
    let content: Content
    var width = SettingsLayout.pickerWidth

    init(
        _ label: String,
        selection: Binding<Value>,
        width: CGFloat = SettingsLayout.pickerWidth,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self._selection = selection
        self.width = width
        self.content = content()
    }

    var body: some View {
        SettingsRow(label) {
            Picker("", selection: $selection) { content }
                .labelsHidden()
                .frame(width: width)
                .accessibilityLabel(label)
        }
    }
}

struct SettingsDateRow: View {
    let label: String
    @Binding var date: Date

    var body: some View {
        SettingsRow(label) {
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(label)
        }
    }
}

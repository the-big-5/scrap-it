import SwiftUI

/// Shared row layout for radio and checkbox: 44pt tall, 12pt gap, Body Normal Regular label.
struct DSControlRow<Control: View, Label: View>: View {
    @ViewBuilder let control: Control
    @ViewBuilder let label: Label

    var body: some View {
        HStack(spacing: 12) {
            control
            label
                .font(DSTypography.normalRegular.font)
                .foregroundStyle(DSColor.Brand.primary)
        }
        .frame(minHeight: dsMinimumTapTarget)
        .contentShape(Rectangle())
    }
}

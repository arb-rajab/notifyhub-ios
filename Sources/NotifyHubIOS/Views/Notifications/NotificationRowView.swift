import SwiftUI

struct NotificationRowView: View {
    let notification: NotificationItem
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notification.title).font(.headline)
            Text(notification.body).font(.body)
            Text("\(notification.author.displayName) · \(notification.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(isHighlighted ? Color.accentColor.opacity(0.15) : nil)
    }
}

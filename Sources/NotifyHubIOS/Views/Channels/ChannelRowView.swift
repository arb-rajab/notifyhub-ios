import SwiftUI

struct ChannelRowView: View {
    let channel: Channel
    let onToggleSubscription: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name).font(.headline)
                Text("#\(channel.slug) · \(channel.subscriberCount) subscribers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(channel.isSubscribed ? "Subscribed" : "Subscribe") {
                onToggleSubscription()
            }
            .buttonStyle(.bordered)
            .tint(channel.isSubscribed ? .secondary : .accentColor)
        }
        .contentShape(Rectangle())
    }
}

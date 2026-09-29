import SwiftUI
import UIKit

/// A small dismissible banner shown over the signed-in UI when push
/// notifications aren't working on this device. Deliberately not a settings
/// screen: the app has no other settings, so there's nothing for one to
/// hold beyond this one message.
struct PushStatusBanner: View {
    @EnvironmentObject private var pushStatus: PushStatus
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let issue = pushStatus.visibleIssue {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.slash")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(message(for: issue))
                        .font(.footnote)
                    if issue == .permissionDenied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                Spacer(minLength: 0)
                Button {
                    pushStatus.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityElement(children: .contain)
        }
    }

    private func message(for issue: PushIssue) -> String {
        switch issue {
        case .permissionDenied:
            return "Notifications are turned off for NotifyHub, so you won't receive pushes. Enable them in Settings, then restart the app."
        case .registrationFailed:
            return "Couldn't set up push notifications on this device, so you may not receive them. It will be retried the next time you sign in or open the app."
        }
    }
}

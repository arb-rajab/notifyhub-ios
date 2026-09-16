import SwiftUI

struct ChannelDetailView: View {
    @StateObject private var viewModel: ChannelDetailViewModel

    init(viewModel: ChannelDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if let channel = viewModel.channel {
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(channel.name).font(.title3.bold())
                                if let description = channel.description {
                                    Text(description).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(channel.isSubscribed ? "Subscribed" : "Subscribe") {
                                Task { await viewModel.toggleSubscription() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if viewModel.channel?.isSubscribed == true {
                    Section("Publish a notification") {
                        TextField("Title", text: $viewModel.composeTitle)
                        TextField("Body", text: $viewModel.composeBody, axis: .vertical)
                        Button("Publish") { Task { await viewModel.publish() } }
                            .disabled(viewModel.composeTitle.isEmpty || viewModel.composeBody.isEmpty)
                    }
                }

                Section("Notifications") {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRowView(
                            notification: notification,
                            isHighlighted: notification.id == viewModel.highlightNotificationId
                        )
                        .id(notification.id)
                    }
                }
            }
            // Single-parameter form deliberately: the two-parameter
            // (oldValue, newValue) `onChange` overload requires iOS 17,
            // this app's deployment target is iOS 16.
            .onChange(of: viewModel.notifications.isEmpty) { isEmpty in
                guard !isEmpty, let target = viewModel.highlightNotificationId else { return }
                withAnimation { proxy.scrollTo(target, anchor: .center) }
            }
        }
        .navigationTitle(viewModel.channel?.name ?? "Channel")
        .task {
            await viewModel.loadInitial()
            viewModel.startLiveUpdates()
        }
        .onDisappear { viewModel.stopLiveUpdates() }
        .alert(
            "Something went wrong",
            isPresented: hasErrorBinding
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var hasErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

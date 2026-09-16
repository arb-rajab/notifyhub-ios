import SwiftUI

struct ChannelListView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var viewModel: ChannelListViewModel
    @State private var showCreateChannel = false

    init(viewModel: ChannelListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(viewModel.channels) { channel in
            NavigationLink(value: AppRoute.channel(slug: channel.slug)) {
                ChannelRowView(channel: channel) {
                    Task { await viewModel.toggleSubscription(for: channel) }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search channels")
        .onSubmit(of: .search) { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .navigationTitle("Channels")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateChannel = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Sign Out", role: .destructive) { session.signOut() }
            }
        }
        .sheet(isPresented: $showCreateChannel) {
            CreateChannelView(viewModel: viewModel)
        }
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

private struct CreateChannelView: View {
    @ObservedObject var viewModel: ChannelListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var slug = ""
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Slug (e.g. release-notes)", text: $slug)
                    .textInputAutocapitalization(.never)
                TextField("Name", text: $name)
                TextField("Description (optional)", text: $description)
            }
            .navigationTitle("New Channel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createChannel(
                                slug: slug,
                                name: name,
                                description: description.isEmpty ? nil : description
                            )
                            dismiss()
                        }
                    }
                    .disabled(slug.isEmpty || name.isEmpty)
                }
            }
        }
    }
}

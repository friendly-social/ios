import SwiftUI

struct AuthBindingsView: View {
    let onEmailLinked: (String) -> Void

    @State private var viewModel = AuthBindingsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("auth_bindings_title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                Text("auth_bindings_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                NavigationLink {
                    EmailBindingView(onSuccess: onEmailLinked)
                } label: {
                    EmailBindingButtonLabel()
                }
                .buttonStyle(.borderedProminent)
                AppleBindingButton(viewModel: viewModel)
                GoogleBindingButton(viewModel: viewModel)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("auth_bindings_navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "auth_bindings_provider_unavailable_title",
            isPresented: $viewModel.showProviderUnavailableAlert,
        ) {
            Button("sign_up_error_ok", role: .cancel) {}
        } message: {
            Text("auth_bindings_provider_unavailable_message")
        }
    }
}

private struct EmailBindingButtonLabel: View {
    var body: some View {
        HStack {
            Image(systemName: "envelope")
            Text("profile_edit_bind_email_button")
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct AppleBindingButton: View {
    let viewModel: AuthBindingsViewModel

    var body: some View {
        Button(action: { viewModel.tapAppleAuthorization() }) {
            HStack {
                Image(systemName: "apple.logo")
                Text("auth_bindings_apple_button")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }
}

private struct GoogleBindingButton: View {
    let viewModel: AuthBindingsViewModel

    var body: some View {
        Button(action: { viewModel.tapGoogleAuthorization() }) {
            HStack {
                Image(systemName: "globe")
                Text("auth_bindings_google_button")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }
}

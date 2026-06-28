import SwiftUI

struct AuthBindingsView: View {
    let onEmailLinked: (String) -> Void

    @State private var viewModel = AuthBindingsViewModel()

    var body: some View {
        ScrollView {
            contentView
                .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(String(localized: .authBindingsNavigationTitle))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            String(localized: .authBindingsProviderUnavailableTitle),
            isPresented: $viewModel.showProviderUnavailableAlert,
        ) {
            Button(String(localized: .signUpErrorOk), role: .cancel) {}
        } message: {
            Text(.authBindingsProviderUnavailableMessage)
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleLabel
            subtitleLabel
            emailBindingNavigationLink
            AppleBindingButton(viewModel: viewModel)
            GoogleBindingButton(viewModel: viewModel)
        }
    }

    private var titleLabel: some View {
        Text(.authBindingsTitle)
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var subtitleLabel: some View {
        Text(.authBindingsSubtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var emailBindingNavigationLink: some View {
        NavigationLink {
            EmailBindingView(onSuccess: onEmailLinked)
        } label: {
            EmailBindingButtonLabel()
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct EmailBindingButtonLabel: View {
    var body: some View {
        HStack {
            Image(systemName: "envelope")
            Text(.profileEditBindEmailButton)
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
                Text(.authBindingsAppleButton)
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
                Text(.authBindingsGoogleButton)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }
}

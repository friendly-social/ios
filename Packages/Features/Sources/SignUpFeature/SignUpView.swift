import AuthFeature
import Flow
import FriendlyUIKit
import PhotosUI
import ProfileFormService
import SwiftUI

public struct SignUpView: View {
    @State private var viewModel: SignUpViewModel
    @State private var path: [WelcomeRoute] = []
    private let onEmailLogin: () -> Void

    public init(
        onSignUp: @escaping () -> Void,
        onEmailLogin: @escaping () -> Void,
        service: ProfileFormService,
    ) {
        self.viewModel = SignUpViewModel(onComplete: onSignUp, service: service)
        self.onEmailLogin = onEmailLogin
    }

    public var body: some View {
        NavigationStack(path: $path) {
            welcomeView
                .navigationDestination(for: WelcomeRoute.self) { route in
                    switch route {
                    case .emailLogin: EmailLoginView(onSuccess: onEmailLogin)
                    case .registration: registrationView
                    }
                }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(.appName)
                .font(.system(size: 64, weight: .black, design: .default))
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    path.append(.emailLogin)
                } label: {
                    Text(.signUpEmailLogin)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.white)
                .foregroundStyle(.black)

                Button {
                    path.append(.registration)
                } label: {
                    Text(.signUpSignUp)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.white)
                .foregroundStyle(.white)
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background { FriendlyAuroraBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var registrationView: some View {
        contentView
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(.signUpSignUp)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    emailLoginNavigationLink
                }
            }
            .preferredColorScheme(nil)
            .safeAreaInset(edge: .bottom) {
                bottomControlsView
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .alert(
                String(localized: .signUpError),
                isPresented: .constant(viewModel.error != nil),
            ) {
                Button(String(localized: .signUpErrorOk)) {
                    viewModel.clearError()
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                if let error = viewModel.error {
                    let resource: LocalizedStringResource = switch error {
                    case .required: .signUpRequiredFields
                    case .nicknameMaxLength: .signUpNicknameMaxLength
                    case .descriptionMaxLength: .signUpDescriptionMaxLength
                    case .socialLinkMaxLength: .signUpSocialLinkMaxLength
                    case .socialLinkNotUrl: .signUpSocialLinkNotUrl
                    case .ioError: .signUpIoError
                    }
                    Text(resource)
                }
            }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(.signUpSignUp)
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                AvatarPicker(viewModel: viewModel)
                Inputs(
                    nickname: $viewModel.nickname,
                    description: $viewModel.description,
                    socialLink: $viewModel.socialLink,
                )
                Interests(viewModel: viewModel)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    private var bottomControlsView: some View {
        SignUpButton(viewModel: viewModel)
            .background(Color(uiColor: .systemGroupedBackground))
    }

    private var emailLoginNavigationLink: some View {
        NavigationLink {
            EmailLoginView(onSuccess: onEmailLogin)
        } label: {
            Text(.signUpEmailLogin)
        }
        .disabled(viewModel.loading || viewModel.uploading)
    }
}

private enum WelcomeRoute: Hashable {
    case emailLogin
    case registration
}

private struct AvatarPicker: View {
    let viewModel: SignUpViewModel

    @State private var selectedItem: PhotosPickerItem? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack {
            if let imageData = viewModel.previewAvatarData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .glassEffect()
                    .overlay {
                        if viewModel.uploading {
                            ZStack {
                                Circle().fill(.ultraThinMaterial)
                                ProgressView().tint(.white)
                            }
                        }
                    }
            } else {
                let opacity = colorScheme == .light ? 0.5 : 1
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .background(.white)
                    .foregroundStyle(.gray.gradient.opacity(opacity))
                    .clipShape(Circle())
                    .glassEffect()
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text(.signUpUpload)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.glass)
            .padding(.vertical, 12)
            .onChange(of: selectedItem) { _, item in viewModel.selectAvatar(item) }
            .onChange(of: viewModel.clearImage) { _, clearImage in
                if clearImage {
                    selectedItem = nil
                    viewModel.clearImage = false
                }
            }
        }
    }

}

private struct Inputs: View {
    @Binding var nickname: String
    @Binding var description: String
    @Binding var socialLink: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.secondary)

                TextField(
                    String(localized: .signUpNickname),
                    text: $nickname
                )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Divider()
                .padding(.vertical)

            HStack {
                Image(systemName: "paperplane")
                    .foregroundColor(.secondary)
                TextField(
                    String(localized: .signUpSocialLink),
                    text: $socialLink,
                    axis: .vertical,
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }

            Divider()
                .padding(.vertical)

            HStack(alignment: .top) {
                Image(systemName: "bubble")
                    .foregroundColor(.secondary)
                TextField(
                    String(localized: .signUpDescription),
                    text: $description,
                    axis: .vertical,
                )
                .lineLimit(3...6)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct Interests: View {
    let viewModel: SignUpViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        HFlow(horizontalAlignment: .center, verticalAlignment: .top) {
            ForEach(viewModel.interests, id: \.string) { interest in
                let isSelected = viewModel.pickedInterests.contains(interest)
                ChipView(text: interest.string, isSelected: isSelected) {
                    viewModel.toggle(interest: interest)
                }
            }
        }
        .padding()
    }
}

private struct SignUpButton: View {
    let viewModel: SignUpViewModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel
        Button(action: { viewModel.clickSignUp() }) {
            ZStack {
                Text(.signUpSignUp)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .opacity(viewModel.loading ? 0 : 1)
                if viewModel.loading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .foregroundStyle(.white)
        .tint(.accentColor)
        .opacity(viewModel.signUpButtonDisabled ? 0.5 : 1)
        .disabled(viewModel.signUpButtonDisabled)
    }
}

import SwiftUI
import PhotosUI
import WidgetKit
import Flow

struct SignUpView: View {
    @State private var viewModel: SignUpViewModel
    private let onEmailLogin: () -> Void

    init(
        onSignUp: @escaping () -> Void,
        onEmailLogin: @escaping () -> Void,
    ) {
        self.viewModel = SignUpViewModel(onComplete: onSignUp)
        self.onEmailLogin = onEmailLogin
    }

    var body: some View {
        NavigationStack {
            contentView
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(.appName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomControlsView
                .padding(.horizontal, 20)
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
    }

    private var contentView: some View {
        ScrollView {
            AvatarPicker(viewModel: viewModel)
            Inputs(
                nickname: $viewModel.nickname,
                description: $viewModel.description,
                socialLink: $viewModel.socialLink,
            )
            Interests(viewModel: viewModel)
        }
    }

    private var bottomControlsView: some View {
        VStack(spacing: 8) {
            SignUpButton(viewModel: viewModel)
            emailLoginNavigationLink
        }
    }

    private var emailLoginNavigationLink: some View {
        NavigationLink {
            EmailLoginView(onSuccess: onEmailLogin)
        } label: {
            Text(.signUpEmailLogin)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.glass)
        .disabled(viewModel.loading || viewModel.uploading)
    }
}

private struct AvatarPicker: View {
    let viewModel: SignUpViewModel

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack {
            if let imageData = selectedImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
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
                    .frame(width: 150, height: 150)
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
            .onChange(of: selectedItem) { _, item in loadImage(item) }
            .onChange(of: viewModel.clearImage) { _, clearImage in
                if clearImage {
                    selectedItem = nil
                    selectedImageData = nil
                    viewModel.clearImage = false
                }
            }
        }
    }

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            guard let data = data else { return }
            await MainActor.run {
                selectedImageData = data
                viewModel.upload(data)
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
        .padding(.horizontal)
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
                    .padding()
                    .opacity(viewModel.loading ? 0 : 1)
                if viewModel.loading {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .buttonStyle(.glassProminent)
        .disabled(viewModel.signUpButtonDisabled)
    }
}

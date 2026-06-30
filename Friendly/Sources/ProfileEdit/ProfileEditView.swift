//
//  ProfileEdit.swift
//  Friendly
//
//  Created by Konstantin on 09.02.2026.
//

import SwiftUI
import PhotosUI
import WidgetKit
import Flow

struct ProfileEditView: View {
    @State private var viewModel: ProfileEditViewModel

    init(
        profileInfo: ProfileInfo,
        onComplete: @escaping () -> Void
    ) {
        self.viewModel = ProfileEditViewModel(
            profileInfo: profileInfo,
            onComplete: onComplete
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationView {
            ScrollView {
                AvatarPicker(viewModel: viewModel)
                Inputs(
                    nickname: $viewModel.nickname,
                    description: $viewModel.description,
                    socialLink: $viewModel.socialLink,
                )
                emailSectionView
                Interests(viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(.profileEdit)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { viewModel.dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                SaveButton(viewModel: viewModel)
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
        .onDisappear {
            viewModel.cancelTasks()
        }
    }

    @ViewBuilder
    private var emailSectionView: some View {
        if let email = viewModel.email {
            EmailInfoView(
                email: email,
                isUnlinking: viewModel.isUnlinkingEmail,
                onUnlink: viewModel.unlinkEmail,
            )
            .padding(.horizontal)
        } else {
            AuthBindingsNavigationButton { email in
                viewModel.emailLinked(email)
                viewModel.dismiss()
            }
            .padding(.horizontal)
        }
    }
}

private struct EmailInfoView: View {
    let email: String
    let isUnlinking: Bool
    let onUnlink: () -> Void

    @State private var showUnlinkConfirmation = false

    var body: some View {
        HStack {
            emailLabelsView
            Spacer()
            unlinkButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
        .confirmationDialog(
            String(localized: .profileEditUnlinkEmailConfirmation),
            isPresented: $showUnlinkConfirmation,
            titleVisibility: .visible,
        ) {
            Button(
                String(localized: .profileEditUnlinkEmailConfirm),
                role: .destructive,
                action: onUnlink,
            )
        }
    }

    private var emailLabelsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(.profileEditEmailTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(email)
                .font(.body)
        }
    }

    @ViewBuilder
    private var unlinkButton: some View {
        if isUnlinking {
            ProgressView()
        } else {
            Button(role: .destructive) {
                showUnlinkConfirmation = true
            } label: {
                Image(systemName: "link.badge.minus")
            }
            .accessibilityLabel(
                String(localized: .profileEditUnlinkEmailButton)
            )
        }
    }
}

private struct AvatarPicker: View {
    let viewModel: ProfileEditViewModel

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

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
                AvatarView(url: viewModel.profileInfo.avatarUrl, size: 150)
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
    let viewModel: ProfileEditViewModel

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

private struct SaveButton: View {
    let viewModel: ProfileEditViewModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel
        Button(action: { viewModel.clicksave() }) {
            ZStack {
                Text(.profileEditButtonSave)
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
        .disabled(viewModel.saveButtonDisabled)
    }
}

private struct AuthBindingsNavigationButton: View {
    let onEmailLinked: (String) -> Void

    var body: some View {
        NavigationLink {
            AuthBindingsView(onEmailLinked: onEmailLinked)
        } label: {
            HStack {
                Image(systemName: "envelope")
                Text(.profileEditAuthBindingsButton)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.glass)
        .padding(.top, 8)
    }
}

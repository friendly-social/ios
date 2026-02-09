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
        NavigationView {
            ScrollView {
                AvatarPicker(viewModel: viewModel)
                Inputs(
                    nickname: $viewModel.nickname,
                    description: $viewModel.description,
                    socialLink: $viewModel.socialLink,
                )
                Interests(viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("profile_edit")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
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
                saveButton(viewModel: viewModel)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .alert(
                "sign_up_error",
                isPresented: .constant(viewModel.error != nil),
            ) {
                Button("sign_up_error_ok") {
                    viewModel.clearError()
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                if let error = viewModel.error {
                    let string: LocalizedStringKey = switch error {
                    case .required: "sign_up_required_fields"
                    case .nicknameMaxLength: "sign_up_nickname_max_length"
                    case .descriptionMaxLength: "sign_up_description_max_length"
                    case .socialLinkMaxLength: "sign_up_social_link_max_length"
                    case .socialLinkNotUrl: "sign_up_social_link_not_url"
                    case .ioError: "sign_up_io_error"
                    }
                    Text(string)
                }
            }
        }
        .onDisappear {
            viewModel.dismiss()
        }
    }
}

private struct AvatarPicker: View {
    let viewModel: ProfileEditViewModel

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
                Text("sign_up_upload")
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

                TextField("sign_up_nickname", text: $nickname)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Divider()
                .padding(.vertical)

            HStack {
                Image(systemName: "paperplane")
                    .foregroundColor(.secondary)
                TextField(
                    "sign_up_social_link",
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
                    "sign_up_description",
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

private struct saveButton: View {
    let viewModel: ProfileEditViewModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel
        Button(action: { viewModel.clicksave() }) {
            ZStack {
                Text("profile_edit_button_save")
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

import SwiftUI
import PhotosUI
import WidgetKit
import Flow

struct SignUpView: View {
    @State private var viewModel = SignUpViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                AvatarPicker(viewModel: viewModel)
                Inputs(
                    nickname: $viewModel.nickname,
                    description: $viewModel.description,
                )
                Interests(viewModel: viewModel)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("app_name")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                }
            }
            .safeAreaInset(edge: .bottom) {
                SignUpButton(viewModel: viewModel)
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
                    case .ioError: "sign_up_io_error"
                    }
                    Text(string)
                }
            }
        }
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
                Text("sign_up_upload")
                    .padding(.vertical, 5)
                    .padding(.horizontal, 20)
            }
            .buttonStyle(.glass)
            .padding(.vertical, 12)
            .onChange(of: selectedItem) { _, item in loadImage(item) }
        }
    }

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            guard let data = data else { return }
            selectedImageData = data
            viewModel.upload(data)
        }
    }
}

private struct Inputs: View {
    @Binding var nickname: String
    @Binding var description: String

    var body: some View {
        VStack(spacing: 0) {
            TextField("sign_up_nickname", text: $nickname)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                // todo: add proper switch to field
                // .submitLabel(.next)
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))

            Divider()
                .padding(.horizontal)

            TextField(
                "sign_up_description",
                text: $description,
                axis: .vertical,
            )
            .lineLimit(3...6)
            .submitLabel(.done)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
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
                Chip(text: interest.string, isSelected: isSelected) {
                    viewModel.toggle(interest: interest)
                }
            }
        }
        .padding()
    }
}

private struct Chip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var pastelColor: Color {
        let lightPastels = [
            Color(red: 1.0, green: 0.8, blue: 0.8),
            Color(red: 0.8, green: 0.9, blue: 1.0),
            Color(red: 0.85, green: 0.95, blue: 0.85),
            Color(red: 1.0, green: 0.9, blue: 0.7),
            Color(red: 0.95, green: 0.8, blue: 1.0),
        ]
        let darkPastels = [
            Color(red: 0.6, green: 0.3, blue: 0.3),
            Color(red: 0.3, green: 0.4, blue: 0.6),
            Color(red: 0.35, green: 0.45, blue: 0.35),
            Color(red: 0.6, green: 0.5, blue: 0.3),
            Color(red: 0.5, green: 0.3, blue: 0.6),
        ]
        let colors = colorScheme == .dark ? darkPastels : lightPastels
        let sum = text.unicodeScalars.reduce(0) { acc, scalar in
            acc + Int(scalar.value)
        }
        let index = abs(sum) % colors.count
        return colors[index]
    }

    var body: some View {
        Button(action: action) {
            if isSelected {
                Text(text)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(pastelColor)
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
            } else {
                Text(text)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(pastelColor.opacity(0.5))
                    .foregroundColor(.primary.opacity(0.5))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct SignUpButton: View {
    let viewModel: SignUpViewModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel
        Button(action: { viewModel.clickSignUp() }) {
            ZStack {
                Text("sign_up_sign_up")
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

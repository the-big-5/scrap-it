import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @Bindable var viewModel: ProfileViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    private static let dividerColor = Color(red: 0.902, green: 0.902, blue: 0.902)

    var body: some View {
        ZStack {
            DSColor.Kraft.lightActive.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: 0) {
                        avatarPicker
                            .padding(.top, 24)

                        if viewModel.hasDraftAvatar {
                            Button("Remove Photo", role: .destructive, action: viewModel.removeDraftAvatar)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DSColor.Component.inputError.color)
                                .padding(.top, 10)
                        }

                        groupedCard {
                            editableRow(label: "Name") {
                                TextField("Your name", text: $viewModel.draftName)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Color.black)
                                    .multilineTextAlignment(.trailing)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                            }

                            Rectangle()
                                .fill(Self.dividerColor)
                                .frame(height: 1)
                                .padding(.leading, 16)

                            editableRow(label: "Bio") {
                                TextField("Add a bio", text: $viewModel.draftBio)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Color.black)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding(.top, 32)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Private Information")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.black)
                                .padding(.leading, 8)

                            groupedCard {
                                editableRow(label: "Email") {
                                    Text(viewModel.emailText)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .padding(.top, 28)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                Button(action: viewModel.requestSignOut) {
                    Text("Log Out")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DSColor.Kraft.light)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(DSColorToken(0x681111)))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.setDraftAvatar(rawData: data)
                }
                selectedPhotoItem = nil
            }
        }
        .confirmationDialog(
            "",
            isPresented: $viewModel.isShowingSignOutConfirmation,
            titleVisibility: .hidden
        ) {
            Button("Log Out", role: .destructive, action: viewModel.confirmSignOut)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
    }

    private var topBar: some View {
        HStack {
            BackCircleButton(action: viewModel.cancelEditProfile)

            Spacer()

            Text("Profile Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DSColor.Brand.primary.color)

            Spacer()

            CircleIconButton(
                systemName: "checkmark",
                accessibilityLabel: "Save profile",
                action: viewModel.saveProfileChanges
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatarView(avatarData: viewModel.draftAvatarData, size: 120)

                Circle()
                    .fill(DSColor.Paper.light.color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(DSColor.Brand.primary.color.opacity(0.25), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "camera")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DSColor.Brand.primary.color)
                    )
                    .offset(x: -2, y: -2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change profile photo")
    }

    private func groupedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DSColor.Paper.lightActive.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(DSColor.Brand.primary.color, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func editableRow<Trailing: View>(label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 17))
                .foregroundStyle(Color.secondary)

            Spacer(minLength: 12)

            trailing()
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 16)
    }
}

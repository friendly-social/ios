import AccountStorageService
import Dependencies
import Foundation
import Models
import AuthApi
import FilesApi
import ProfileApi
import PhotosUI
import ProfileFormService
import SwiftUI
import UIKit

struct ProfileFormServiceLive: Sendable {
  @Dependency(AuthApi.self) private var authApi
  @Dependency(FilesApi.self) private var filesApi
  @Dependency(ProfileApi.self) private var profileApi
  @Dependency(AccountStorageService.self) private var storage

  func loadAvatar(_ item: PhotosPickerItem) async throws -> Data {
    guard let data = try await item.loadTransferable(type: Data.self) else {
      throw ProfileFormError.invalidImage
    }
    return data
  }

  func uploadAvatar(_ data: Data) async throws -> FileDescriptor {
    guard let image = UIImage(data: data),
          let compressed = image.resize(maxDimension: 256).jpegData(compressionQuality: 0.7)
    else { throw ProfileFormError.invalidImage }
    return try await filesApi.upload(compressed)
  }

  func signUp(
    nickname: Nickname,
    description: UserDescription,
    interests: [Interest],
    avatar: FileDescriptor?,
    socialLink: SocialLink?
  ) async throws {
    let authorization = try await authApi.authGenerate(
      nickname,
      description,
      interests,
      avatar,
      socialLink)
    try storage.saveAuthorization(authorization)
  }

  func updateProfile(
    nickname: Nickname,
    description: UserDescription,
    interests: [Interest],
    avatar: FileDescriptor?,
    socialLink: SocialLink?
  ) async throws {
    let authorization = try storage.loadAuthorization()
    try await profileApi.usersEdit(
      authorization,
      nickname,
      description,
      interests,
      avatar,
      socialLink)
  }

  func unlinkEmail() async throws {
    let authorization = try storage.loadAuthorization()
    try await authApi.emailUnlink(authorization)
  }
}

private enum ProfileFormError: Error {
  case invalidImage
}

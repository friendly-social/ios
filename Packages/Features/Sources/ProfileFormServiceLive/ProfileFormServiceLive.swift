import AccountStorageService
import AuthApi
import Dependencies
import FilesApi
import Foundation
import Models
import PhotosUI
import ProfileApi
import PushRegistrationService
import SwiftUI
import UIKit

struct ProfileFormServiceLive: Sendable {
  @Dependency(AuthApi.self) private var authApi
  @Dependency(FilesApi.self) private var filesApi
  @Dependency(ProfileApi.self) private var profileApi
  @Dependency(AccountStorageService.self) private var storage
  @Dependency(PushRegistrationService.self) private var pushRegistration

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
    guard try storage.hasAuthorization() else { return try await filesApi.upload(compressed) }
    let authorization = try storage.loadAuthorization()
    let credentials = FilesApi.UploadCredentials(
      accountID: authorization.id.int64, token: authorization.token.string)
    let descriptor = try await filesApi.uploadAuthorized(compressed, credentials)
    try Task.checkCancellation()
    guard let current = try? storage.loadAuthorization(),
          current.id == authorization.id, current.token == authorization.token else {
      throw CancellationError()
    }
    return descriptor
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
    pushRegistration.refresh()
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

import DependenciesMacros
import Foundation
import Models
import PhotosUI
import SwiftUI

@DependencyClient
public struct ProfileFormService: Sendable {
  public var loadAvatar: @Sendable (PhotosPickerItem) async throws -> Data
  public var uploadAvatar: @Sendable (Data) async throws -> FileDescriptor
  public var signUp: @Sendable (
    Nickname, UserDescription, [Interest], FileDescriptor?, SocialLink?
  ) async throws -> Void
  public var updateProfile: @Sendable (
    Nickname, UserDescription, [Interest], FileDescriptor?, SocialLink?
  ) async throws -> Void
  public var unlinkEmail: @Sendable () async throws -> Void
}

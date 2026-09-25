import Dependencies
import Foundation
import Models
import Networking
import ProfileApi

struct ProfileApiLive: Sendable {
  @Dependency(HTTPClient.self) private var client

  func details(
    _ authorization: Authorization,
    _ id: UserId,
    _ accessHash: UserAccessHash
  ) async throws -> UserDetails {
    let options = HTTPClient.Request.Options(
      urlPath: "users/details/\(id.int64)/\(accessHash.string)",
      headers: authorizationHeaders(authorization))
    do {
      let response: UserDetailsDTO = try await client.push(request: .get(options: options))
      do { return try response.userDetails() }
      catch { throw ProfileApi.UserDetailsError.serverError }
    } catch let error as HTTPStatusError {
      throw error.response.statusCode == 401
        ? ProfileApi.UserDetailsError.unauthorized : .serverError
    } catch let error as ProfileApi.UserDetailsError { throw error }
      catch { throw ProfileApi.UserDetailsError.ioError(error) }
  }

  func edit(
    _ authorization: Authorization,
    _ nickname: Nickname,
    _ description: UserDescription,
    _ interests: [Interest],
    _ avatar: FileDescriptor?,
    _ socialLink: SocialLink?
  ) async throws {
    let body = UserEditBody(
      nickname: nickname.string, description: description.string,
      interests: interests.map(\.string), avatar: avatar.map(ProfileFileDTO.init),
      socialLink: socialLink?.string)
    let options = HTTPClient.Request.Options(
      urlPath: "users/edit", headers: authorizationHeaders(authorization))
    do {
      let request = try HTTPClient.Request.patch(options: options, body: body)
      let response = try await client.send(request)
      guard response.statusCode == 200 else { throw HTTPStatusError(response: response) }
    } catch let error as HTTPStatusError {
      throw error.response.statusCode == 401
        ? ProfileApi.UserDetailsError.unauthorized : .serverError
    } catch { throw ProfileApi.UserDetailsError.ioError(error) }
  }
}

private extension ProfileApiLive {
  private func authorizationHeaders(_ authorization: Authorization) -> [String: String] {
    [
      "Cache-Control": "no-cache",
      "X-Token": authorization.token.string,
      "X-User-Id": String(authorization.id.int64)
    ]
  }
}

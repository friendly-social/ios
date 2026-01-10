struct NetworkDetailsSerializable: Codable {
    let friends: [UserDetailsSerializable]

    func typed() throws -> NetworkDetails {
        return NetworkDetails(
            friends: try friends.map { user in try user.typed() },
        )
    }
}

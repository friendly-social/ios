struct NetworkDetails {
    let friends: [UserDetails]

    func serializable() -> NetworkDetailsSerializable {
        return NetworkDetailsSerializable(
            friends: friends.map { user in user.serializable() },
        )
    }
}

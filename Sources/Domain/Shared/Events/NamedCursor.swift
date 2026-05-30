package struct NamedCursor: Sendable, Equatable {

    package let name: String
    package let value: String

    package init(
        name: String,
        value: String
    ) {
        self.name = name
        self.value = value
    }

}

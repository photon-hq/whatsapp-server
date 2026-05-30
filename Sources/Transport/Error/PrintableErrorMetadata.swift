func boundedPrintableASCII(_ value: String) -> String {
    let suffix = "...[truncated]"
    let maxLength = 256
    let printable = String(value.unicodeScalars.filter { scalar in
        scalar.value >= 0x20 && scalar.value <= 0x7E
    })

    guard printable.count > maxLength else {
        return printable
    }

    return String(printable.prefix(maxLength - suffix.count)) + suffix
}

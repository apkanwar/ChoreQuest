import SwiftUI

struct Kid: Identifiable, Hashable, Codable {
    static let defaultColorHex = "#4F46E5"

    let id: String
    var name: String
    var colorHex: String
    var coins: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String = Kid.defaultColorHex,
        coins: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.coins = coins
    }

    var color: Color { Color(hex: colorHex) }
    var initial: String { String(name.prefix(1)).uppercased() }

    func updatingColor(_ newColor: Color) -> Kid {
        Kid(id: id, name: name, colorHex: newColor.hexString ?? colorHex, coins: coins)
    }
}

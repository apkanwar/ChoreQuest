import SwiftUI

struct Kid: Identifiable, Hashable {
    let id: UUID
    var name: String
    var color: Color
    var coins: Int

    init(id: UUID = UUID(), name: String, color: Color, coins: Int) {
        self.id = id
        self.name = name
        self.color = color
        self.coins = coins
    }

    var initial: String { String(name.prefix(1)).uppercased() }
}

#if DEBUG
extension Kid {
    static let previewList: [Kid] = [
        Kid(name: "Akam", color: .pink, coins: 45),
        Kid(name: "Ashley", color: .yellow, coins: 15),
        Kid(name: "Sunny", color: .green, coins: 120)
    ]
}
#endif

import SwiftUI

#if DEBUG
extension Kid {
    static var preview: Kid {
        Kid(name: "Alex", colorHex: Color.blue.hexString ?? Kid.defaultColorHex, coins: 12)
    }

    static var previewList: [Kid] {
        [
            Kid(name: "Alex", colorHex: Color.blue.hexString ?? Kid.defaultColorHex, coins: 12),
            Kid(name: "Bella", colorHex: Color.pink.hexString ?? Kid.defaultColorHex, coins: 8),
            Kid(name: "Charlie", colorHex: Color.green.hexString ?? Kid.defaultColorHex, coins: 20)
        ]
    }
}
#endif

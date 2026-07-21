import UIKit

// Injected colour palette for dice rendering — D-013, §10.
// Built from app-layer colour tokens at the call site; never imported into the app-layer type system here.
// At SyLibDice extraction time this struct ships in the package unchanged.
struct DiceTintPalette {
    var normal: UIColor      // rolling / unselected
    var held: UIColor        // held aside for next roll
    var nudgeable: UIColor   // yellow: stuck, tap to nudge
    var stuck: UIColor       // red: nudge failed, tap to reroll
    var pip: UIColor         // dot faces (rolling / unselected)
    var heldPip: UIColor     // dot faces when die is held (white on near-black for Paper)
}

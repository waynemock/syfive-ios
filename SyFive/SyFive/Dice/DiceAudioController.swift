/// Hook points for dice audio effects.
///
/// Implement this protocol and assign to `DiceRoller.audioController` to add sound.
/// All methods have empty default implementations so partial adoption is safe.
///
/// - Note: `onDieHitFloor` and `onDieHitWall` are reserved for a future phase
///   that adds RealityKit collision event subscriptions. They are never called yet.
protocol DiceAudioControlling: AnyObject {
    /// Called the moment a die receives its launch impulse.
    func onDieLaunched(index: Int)

    /// Called when a die's velocity first touches the floor. (Future — not yet wired.)
    func onDieHitFloor(index: Int)

    /// Called when a die's velocity first contacts a wall. (Future — not yet wired.)
    func onDieHitWall(index: Int)

    /// Called once per die when its motion has settled.
    func onDieSettled(index: Int, value: Int)

    /// Called after all dice have settled, with the full result array.
    func onAllDiceSettled(values: [Int])
}

// Default no-op implementations — conformers only override what they need.
extension DiceAudioControlling {
    func onDieLaunched(index: Int) {}
    func onDieHitFloor(index: Int) {}
    func onDieHitWall(index: Int) {}
    func onDieSettled(index: Int, value: Int) {}
    func onAllDiceSettled(values: [Int]) {}
}

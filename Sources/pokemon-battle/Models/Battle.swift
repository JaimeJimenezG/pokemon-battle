import Foundation

enum BattleResult {
    case playerWon
    case opponentWon
    case inProgress
}

struct Battle {
    let playerPokemon: Pokemon
    let opponentPokemon: Pokemon
    var currentTurn: Int = 0
    var playerHP: Int
    var opponentHP: Int
    var result: BattleResult = .inProgress
    
    init(playerPokemon: Pokemon, opponentPokemon: Pokemon) {
        self.playerPokemon = playerPokemon
        self.opponentPokemon = opponentPokemon
        self.playerHP = playerPokemon.hp
        self.opponentHP = opponentPokemon.hp
    }
    
    mutating func performTurn() {
        currentTurn += 1
        
        // Player attacks
        let playerDamage = calculateDamage(attacker: playerPokemon, defender: opponentPokemon)
        opponentHP -= playerDamage
        
        if opponentHP <= 0 {
            result = .playerWon
            return
        }
        
        // Opponent attacks
        let opponentDamage = calculateDamage(attacker: opponentPokemon, defender: playerPokemon)
        playerHP -= opponentDamage
        
        if playerHP <= 0 {
            result = .opponentWon
            return
        }
    }
    
    private func calculateDamage(attacker: Pokemon, defender: Pokemon) -> Int {
        let attackStat = attacker.attack
        let defenseStat = defender.defense
        
        let baseDamage = Double(attackStat) / Double(defenseStat) * 20.0
        let randomFactor = Double.random(in: 0.85...1.15)
        
        return Int(baseDamage * randomFactor)
    }
} 
import Foundation

struct Pokemon: Identifiable, Codable {
    let id: Int
    let name: String
    let hp: Int
    let attack: Int
    let defense: Int
    let specialAttack: Int
    let specialDefense: Int
    let speed: Int
    let types: [String]
    let abilities: [String]
    let moves: [String]
    let description: String
    let height: Int
    let weight: Int
    let baseExperience: Int?
    let captureRate: Int
    let growthRate: String
    let habitat: String
    
    var imageURL: URL {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(id).png")!
    }
    
    var spriteURL: URL {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")!
    }
    
    var totalStats: Int {
        hp + attack + defense + specialAttack + specialDefense + speed
    }
    
    var averageStats: Double {
        Double(totalStats) / 6.0
    }
    
    var primaryType: String {
        types.first ?? "unknown"
    }
    
    var primaryAbility: String {
        abilities.first ?? "unknown"
    }
    
    var primaryMove: String {
        moves.first ?? "unknown"
    }
} 
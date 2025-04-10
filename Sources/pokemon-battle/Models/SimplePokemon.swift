import Foundation

struct SimplePokemon: Identifiable, Codable {
    let id: Int
    let name: String
    
    var imageURL: URL {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/\(id).png")!
    }
    
    var spriteURL: URL {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")!
    }
} 
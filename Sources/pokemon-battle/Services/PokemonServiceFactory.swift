import Foundation

enum PokemonServiceType {
    case primary
    case alternative
}

class PokemonServiceFactory {
    static let shared = PokemonServiceFactory()
    
    private var primaryService: PokemonService?
    private var alternativeService: AlternativePokemonService?
    
    private init() {}
    
    func getService(type: PokemonServiceType = .primary) -> any PokemonServiceProtocol {
        switch type {
        case .primary:
            if primaryService == nil {
                primaryService = PokemonService()
            }
            return primaryService!
            
        case .alternative:
            if alternativeService == nil {
                alternativeService = AlternativePokemonService()
            }
            return alternativeService!
        }
    }
    
    func resetServices() {
        primaryService = nil
        alternativeService = nil
    }
} 
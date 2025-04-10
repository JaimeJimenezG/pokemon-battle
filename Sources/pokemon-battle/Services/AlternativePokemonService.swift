import Foundation

// This service uses the PokéAPI v2 for basic data and adds more detailed information
struct AlternativePokemonService: PokemonServiceProtocol {
    private let baseURL = "https://pokeapi.co/api/v2"
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    private let requestTimeout: TimeInterval = 10.0
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    // Helper function to add a timeout to any async operation
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw PokemonServiceError.timeout
            }
            
            // Return the first result or throw the first error
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func fetch<T: Decodable>(url: URL) async throws -> T {
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PokemonServiceError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw PokemonServiceError.invalidData
                }
            case 429: // Too Many Requests
                throw PokemonServiceError.maxRetriesReached
            case 500...599: // Server Errors
                throw PokemonServiceError.maxRetriesReached
            default:
                throw PokemonServiceError.invalidResponse
            }
        } catch {
            print("Error fetching from URL \(url): \(error)")
            throw error
        }
    }
    
    func fetchPokemon(id: Int) async throws -> Pokemon {
        let url = URL(string: "\(baseURL)/pokemon/\(id)")!
        do {
            // Fetch basic Pokemon data
            let pokemonData: PokemonAPIData = try await withTimeout(seconds: requestTimeout) {
                try await fetch(url: url)
            }
            
            // Fetch species data for more details
            let speciesURL = URL(string: pokemonData.species.url)!
            let speciesData: PokemonSpeciesData = try await withTimeout(seconds: requestTimeout) {
                try await fetch(url: speciesURL)
            }
            
            // Create a more detailed Pokemon object
            return Pokemon(
                id: pokemonData.id,
                name: pokemonData.name,
                hp: pokemonData.stats.first { $0.stat.name == "hp" }?.baseStat ?? 100,
                attack: pokemonData.stats.first { $0.stat.name == "attack" }?.baseStat ?? 50,
                defense: pokemonData.stats.first { $0.stat.name == "defense" }?.baseStat ?? 50,
                specialAttack: pokemonData.stats.first { $0.stat.name == "special-attack" }?.baseStat ?? 50,
                specialDefense: pokemonData.stats.first { $0.stat.name == "special-defense" }?.baseStat ?? 50,
                speed: pokemonData.stats.first { $0.stat.name == "speed" }?.baseStat ?? 50,
                types: pokemonData.types.map { $0.type.name },
                abilities: pokemonData.abilities.map { $0.ability.name },
                moves: pokemonData.moves.prefix(4).map { $0.move.name },
                description: speciesData.flavorTextEntries.first { $0.language.name == "en" }?.flavorText ?? "No description available",
                height: pokemonData.height,
                weight: pokemonData.weight,
                baseExperience: pokemonData.baseExperience,
                captureRate: speciesData.captureRate,
                growthRate: speciesData.growthRate.name,
                habitat: speciesData.habitat?.name ?? "unknown"
            )
        } catch {
            print("Error fetching Pokemon with ID \(id): \(error)")
            throw error
        }
    }
    
    func fetchPokemonList(limit: Int = 151, offset: Int = 0) async throws -> [SimplePokemon] {
        let url = URL(string: "\(baseURL)/pokemon?limit=\(limit)&offset=\(offset)")!
        do {
            let response: PokemonListResponse = try await withTimeout(seconds: requestTimeout) {
                try await fetch(url: url)
            }
            
            return response.results.enumerated().map { index, result in
                SimplePokemon(id: index + 1, name: result.name)
            }
        } catch {
            print("Error fetching Pokemon list: \(error)")
            throw error
        }
    }
    
    func fetchPokemonDetails(id: Int) async throws -> Pokemon {
        return try await fetchPokemon(id: id)
    }
}

// API Response Models
struct PokemonAPIData: Codable {
    let id: Int
    let name: String
    let baseExperience: Int?
    let height: Int
    let weight: Int
    let stats: [StatData]
    let types: [TypeData]
    let abilities: [AbilityData]
    let moves: [MoveData]
    let species: SpeciesReference
}

struct StatData: Codable {
    let baseStat: Int
    let effort: Int
    let stat: StatReference
}

struct StatReference: Codable {
    let name: String
    let url: String
}

struct TypeData: Codable {
    let slot: Int
    let type: TypeReference
}

struct TypeReference: Codable {
    let name: String
    let url: String
}

struct AbilityData: Codable {
    let ability: AbilityReference
    let isHidden: Bool
    let slot: Int
}

struct AbilityReference: Codable {
    let name: String
    let url: String
}

struct MoveData: Codable {
    let move: MoveReference
}

struct MoveReference: Codable {
    let name: String
    let url: String
}

struct SpeciesReference: Codable {
    let name: String
    let url: String
}

struct PokemonSpeciesData: Codable {
    let captureRate: Int
    let growthRate: GrowthRateReference
    let habitat: HabitatReference?
    let flavorTextEntries: [FlavorTextEntry]
}

struct GrowthRateReference: Codable {
    let name: String
    let url: String
}

struct HabitatReference: Codable {
    let name: String
    let url: String
}

struct FlavorTextEntry: Codable {
    let flavorText: String
    let language: LanguageReference
}

struct LanguageReference: Codable {
    let name: String
    let url: String
} 
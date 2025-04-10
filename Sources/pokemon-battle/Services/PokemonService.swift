import Foundation

protocol PokemonServiceProtocol {
    func fetchPokemonList(limit: Int, offset: Int) async throws -> [SimplePokemon]
    func fetchPokemon(id: Int) async throws -> Pokemon
}

enum PokemonServiceError: Error {
    case networkError(Error)
    case invalidResponse
    case maxRetriesReached
    case invalidData
    case connectionFailure
    case pathNotFound
    case noLocalEndpoint
    case quicConnectionError
    case timeout
}

struct PokemonService: PokemonServiceProtocol {
    // Using the official PokeAPI v2 endpoint
    private let baseURL = "https://pokeapi.co/api/v2"
    private let maxRetries = 5
    private let retryDelay: TimeInterval = 2.0
    private let requestTimeout: TimeInterval = 15.0
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        #if os(iOS)
        // iOS simulator specific configuration
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        #endif
        return URLSession(configuration: config)
    }()
    
    private func fetchWithRetry<T: Decodable>(url: URL, attempt: Int = 0) async throws -> T {
        print("🔍 Fetching URL: \(url.absoluteString) (Attempt \(attempt + 1)/\(maxRetries))")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type: \(type(of: response))")
                throw PokemonServiceError.invalidResponse
            }
            
            print("📡 Response status code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    print("✅ Successfully decoded data of type: \(T.self)")
                    return decodedData
                } catch {
                    print("❌ Decoding error: \(error)")
                    print("📄 Raw data: \(String(data: data, encoding: .utf8) ?? "Unable to convert to string")")
                    throw PokemonServiceError.invalidData
                }
            case 429: // Too Many Requests
                if attempt < maxRetries {
                    let delay = retryDelay * Double(attempt + 1)
                    print("⚠️ Rate limited, waiting \(delay) seconds before retry \(attempt + 1)/\(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await fetchWithRetry(url: url, attempt: attempt + 1)
                } else {
                    print("❌ Max retries reached for rate limit")
                    throw PokemonServiceError.maxRetriesReached
                }
            case 500...599: // Server Errors
                if attempt < maxRetries {
                    let delay = retryDelay * Double(attempt + 1)
                    print("⚠️ Server error, waiting \(delay) seconds before retry \(attempt + 1)/\(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await fetchWithRetry(url: url, attempt: attempt + 1)
                } else {
                    print("❌ Max retries reached for server error")
                    throw PokemonServiceError.maxRetriesReached
                }
            default:
                print("❌ Unexpected status code: \(httpResponse.statusCode)")
                throw PokemonServiceError.invalidResponse
            }
        } catch let error as URLError {
            print("❌ URLError: \(error.localizedDescription), code: \(error.code.rawValue)")
            print("🔍 Error details: \(error)")
            
            let isIOSSimulatorError: Bool = {
                #if os(iOS)
                return error.localizedDescription.contains("nw_protocol_implementation_lookup_path") ||
                       error.localizedDescription.contains("No path found")
                #else
                return false
                #endif
            }()

            if error.code == .notConnectedToInternet || 
               error.code == .networkConnectionLost ||
               error.localizedDescription.contains("connection was lost") ||
               isIOSSimulatorError {
                if attempt < maxRetries {
                    let delay = retryDelay * Double(attempt + 1)
                    print("⚠️ Connection lost, waiting \(delay) seconds before retry \(attempt + 1)/\(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await fetchWithRetry(url: url, attempt: attempt + 1)
                } else {
                    print("❌ Max retries reached for connection failure")
                    throw PokemonServiceError.connectionFailure
                }
            }
            
            switch error.code {
            case .timedOut:
                if attempt < maxRetries {
                    let delay = retryDelay * Double(attempt + 1)
                    print("⚠️ Timeout, waiting \(delay) seconds before retry \(attempt + 1)/\(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await fetchWithRetry(url: url, attempt: attempt + 1)
                } else {
                    print("❌ Max retries reached for timeout")
                    throw PokemonServiceError.timeout
                }
            default:
                if attempt < maxRetries {
                    let delay = retryDelay * Double(attempt + 1)
                    print("⚠️ Network error, waiting \(delay) seconds before retry \(attempt + 1)/\(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await fetchWithRetry(url: url, attempt: attempt + 1)
                } else {
                    print("❌ Max retries reached for network error")
                    throw PokemonServiceError.networkError(error)
                }
            }
        }
    }
    
    func fetchPokemon(id: Int) async throws -> Pokemon {
        print("🔍 Fetching Pokemon with ID: \(id)")
        let url = URL(string: "\(baseURL)/pokemon/\(id)")!
        do {
            let pokemonData: PokeAPIPokemon = try await fetchWithRetry(url: url)
            print("✅ Successfully fetched Pokemon: \(pokemonData.name)")
            return try mapPokeAPIToPokemon(pokemonData)
        } catch {
            print("❌ Error fetching Pokemon with ID \(id): \(error)")
            throw error
        }
    }
    
    func fetchPokemonList(limit: Int = 151, offset: Int = 0) async throws -> [SimplePokemon] {
        print("🔍 Fetching Pokemon list with limit: \(limit), offset: \(offset)")
        let url = URL(string: "\(baseURL)/pokemon?limit=\(limit)&offset=\(offset)")!
        do {
            let response: PokemonListResponse = try await fetchWithRetry(url: url)
            print("✅ Successfully fetched Pokemon list with \(response.results.count) results")
            let pokemons = response.results.enumerated().map { index, result in
                SimplePokemon(id: index + offset + 1, name: result.name)
            }
            print("✅ Mapped to \(pokemons.count) SimplePokemon objects")
            return pokemons
        } catch {
            print("❌ Error fetching Pokemon list: \(error)")
            throw error
        }
    }
    
    private func mapPokeAPIToPokemon(_ apiPokemon: PokeAPIPokemon) throws -> Pokemon {
        // Extract stats
        let stats = apiPokemon.stats.reduce(into: [String: Int]()) { result, stat in
            result[stat.stat.name] = stat.baseStat
        }
        
        // Extract types
        let types = apiPokemon.types.map { $0.type.name }
        
        // Extract abilities
        let abilities = apiPokemon.abilities.map { $0.ability.name }
        
        // Extract moves (limited to first 4)
        let moves = apiPokemon.moves.prefix(4).map { $0.move.name }
        
        return Pokemon(
            id: apiPokemon.id,
            name: apiPokemon.name,
            hp: stats["hp"] ?? 0,
            attack: stats["attack"] ?? 0,
            defense: stats["defense"] ?? 0,
            specialAttack: stats["special-attack"] ?? 0,
            specialDefense: stats["special-defense"] ?? 0,
            speed: stats["speed"] ?? 0,
            types: types,
            abilities: abilities,
            moves: moves,
            description: "", // This would require an additional API call
            height: apiPokemon.height,
            weight: apiPokemon.weight,
            baseExperience: apiPokemon.baseExperience,
            captureRate: 0, // This would require an additional API call
            growthRate: "", // This would require an additional API call
            habitat: "" // This would require an additional API call
        )
    }
}

// PokeAPI v2 Response Models
struct PokemonListResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [PokemonResult]
    
    struct PokemonResult: Codable {
        let name: String
        let url: String
    }
}

struct PokeAPIPokemon: Codable {
    let id: Int
    let name: String
    let baseExperience: Int?
    let height: Int
    let weight: Int
    let stats: [Stat]
    let types: [PokemonType]
    let abilities: [Ability]
    let moves: [Move]
    
    struct Stat: Codable {
        let baseStat: Int
        let effort: Int
        let stat: NamedResource
        
        enum CodingKeys: String, CodingKey {
            case baseStat = "base_stat"
            case effort
            case stat
        }
    }
    
    struct PokemonType: Codable {
        let slot: Int
        let type: NamedResource
    }
    
    struct Ability: Codable {
        let ability: NamedResource
        let isHidden: Bool
        let slot: Int
        
        enum CodingKeys: String, CodingKey {
            case ability
            case isHidden = "is_hidden"
            case slot
        }
    }
    
    struct Move: Codable {
        let move: NamedResource
    }
    
    struct NamedResource: Codable {
        let name: String
        let url: String
    }
} 
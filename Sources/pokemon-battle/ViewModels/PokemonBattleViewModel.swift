import Foundation
import SwiftUI

@MainActor
class PokemonBattleViewModel: ObservableObject {
    private let pokemonService = PokemonService()
    
    @Published var availablePokemons: [SimplePokemon] = []
    @Published var selectedTeam: [Pokemon] = []
    @Published var opponentTeam: [Pokemon] = []
    @Published var currentPokemonIndex: Int = 0
    @Published var currentOpponentIndex: Int = 0
    @Published var isLoading = false
    @Published var loadingPokemonId: Int?
    @Published var errorMessage: String?
    @Published var showErrorPopup: Bool = false
    @Published var battleResult: BattleResult?
    @Published var playerHP: Int = 100
    @Published var opponentHP: Int = 100
    @Published var searchText: String = ""
    
    var filteredPokemons: [SimplePokemon] {
        guard !searchText.isEmpty else { return availablePokemons }
        return availablePokemons.filter { pokemon in
            let matchesName = pokemon.name.lowercased().contains(searchText.lowercased())
            let matchesId = String(pokemon.id).contains(searchText)
            return matchesName || matchesId
        }
    }
    
    enum BattleState {
        case selectingTeam
        case battling
        case finished
    }
    
    @Published var battleState: BattleState = .selectingTeam
    
    var isTeamFull: Bool {
        selectedTeam.count >= 5
    }
    
    private func handleError(_ error: Error) {
        print("Error occurred: \(error)")
        
        // Always reset loading states when an error occurs
        isLoading = false
        loadingPokemonId = nil
        
        // Cancel any existing auto-clear task
        autoClearTask?.cancel()
        
        // Reset error state to ensure we can show new errors
        errorMessage = nil
        showErrorPopup = false
        
        if let pokemonError = error as? PokemonServiceError {
            switch pokemonError {
            case .networkError(let underlyingError):
                print("Network error: \(underlyingError)")
                if (underlyingError as NSError).code == NSURLErrorNotConnectedToInternet {
                    errorMessage = "No internet connection. Please check your connection and try again."
                } else {
                    errorMessage = "Network error: \(underlyingError.localizedDescription). Retrying automatically..."
                }
                showErrorPopup = true
            case .connectionFailure:
                print("Connection failure")
                errorMessage = "Connection failed. Please check your internet connection and try again."
                showErrorPopup = true
            case .pathNotFound:
                print("Path not found")
                errorMessage = "Network path not found. Please check your internet connection and try again."
                showErrorPopup = true
            case .noLocalEndpoint:
                print("No local endpoint")
                errorMessage = "Connection error: No local endpoint available. Please check your network settings and try again."
                showErrorPopup = true
            case .quicConnectionError:
                print("QUIC connection error")
                errorMessage = "Connection error: QUIC protocol issue. Please check your internet connection and try again."
                showErrorPopup = true
            case .timeout:
                print("Request timeout")
                errorMessage = "Request timed out. Please check your internet connection and try again."
                showErrorPopup = true
            case .invalidResponse:
                print("Invalid response")
                errorMessage = "Invalid response from server. Please try again."
                showErrorPopup = true
            case .maxRetriesReached:
                print("Max retries reached")
                errorMessage = "Unable to connect after several attempts. Please try again later."
                showErrorPopup = true
            case .invalidData:
                print("Invalid data")
                errorMessage = "Unable to process Pokemon data. Please try again."
                showErrorPopup = true
            }
        } else {
            print("Unexpected error: \(error)")
            
            // Check for specific error messages in the error description
            let errorDescription = String(describing: error)
            if errorDescription.contains("Connection has no local endpoint") {
                errorMessage = "Connection error: No local endpoint available. Please check your network settings and try again."
            } else if errorDescription.contains("quic_conn_retire_dcid") ||
                      errorDescription.contains("quic_conn_change_current_path") {
                errorMessage = "Connection error: QUIC protocol issue. Please check your internet connection and try again."
            } else if errorDescription.contains("No path found") ||
                      errorDescription.contains("tried to change paths") {
                errorMessage = "Network path not found. Please check your internet connection and try again."
            } else if errorDescription.contains("received failure notification") {
                errorMessage = "Connection failed. Please check your internet connection and try again."
            } else if errorDescription.contains("timeout") {
                errorMessage = "Request timed out. Please check your internet connection and try again."
            } else {
                errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }
            
            showErrorPopup = true
        }
        
        print("Error message set to: \(errorMessage ?? "nil")")
        print("Show error popup: \(showErrorPopup)")
        
        // Auto-clear error message and popup after 10 seconds (increased from 5)
        autoClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !Task.isCancelled {
                errorMessage = nil
                showErrorPopup = false
            }
        }
    }
    
    // Add property to track auto-clear task
    private var autoClearTask: Task<Void, Never>?
    
    // Add method to manually clear error state
    func clearError() {
        autoClearTask?.cancel()
        errorMessage = nil
        showErrorPopup = false
        // Ensure loading states are reset when error is cleared
        loadingPokemonId = nil
    }
    
    func loadPokemons() async {
        print("🔄 Starting to load Pokemon list")
        guard availablePokemons.isEmpty else {
            print("ℹ️ Pokemon list already loaded with \(availablePokemons.count) Pokemon")
            return
        }
        isLoading = true
        print("⏳ Setting isLoading to true")
        do {
            print("🔍 Calling pokemonService.fetchPokemonList")
            availablePokemons = try await pokemonService.fetchPokemonList(limit: 151, offset: 0)
            print("✅ Successfully loaded \(availablePokemons.count) Pokemon")
        } catch {
            print("❌ Error in loadPokemons: \(error)")
            handleError(error)
        }
        isLoading = false
        print("⏳ Setting isLoading to false")
    }
    
    func selectPokemon(id: Int) async {
        guard !isTeamFull else { return }
        guard loadingPokemonId == nil else { return }
        
        loadingPokemonId = id
        do {
            let pokemon = try await pokemonService.fetchPokemon(id: id)
            
            // Check again in case user removed Pokemon while loading
            if !isTeamFull {
                selectedTeam.append(pokemon)
            }
            
            if selectedTeam.count == 5 {
                // Generate opponent team
                opponentTeam = []
                for _ in 0..<5 {
                    do {
                        let opponentId = Int.random(in: 1...151)
                        let opponent = try await pokemonService.fetchPokemon(id: opponentId)
                        opponentTeam.append(opponent)
                    } catch {
                        handleError(error)
                        // If there's an error while generating opponent team, remove the last selected Pokemon
                        if !opponentTeam.isEmpty {
                            opponentTeam.removeLast()
                        }
                        throw error
                    }
                }
                
                if opponentTeam.count == 5 {
                    battleState = .battling
                    playerHP = selectedTeam[currentPokemonIndex].hp
                    opponentHP = opponentTeam[currentOpponentIndex].hp
                }
            }
        } catch {
            handleError(error)
            // If there's an error while generating opponent team, reset the battle state
            if selectedTeam.count == 5 {
                selectedTeam.removeLast()
            }
        }
        // Always reset loadingPokemonId, even if there's an error
        loadingPokemonId = nil
    }
    
    func removePokemonFromTeam(at index: Int) {
        guard index < selectedTeam.count else { return }
        selectedTeam.remove(at: index)
        
        // Reset battle-related state
        battleState = .selectingTeam
        opponentTeam = []
        currentPokemonIndex = 0
        currentOpponentIndex = 0
        playerHP = 100
        opponentHP = 100
        battleResult = nil
        loadingPokemonId = nil
    }
    
    struct BattleTurnResult {
        let playerDamage: Int
        let opponentDamage: Int
        let opponentMove: String
    }
    
    func performBattleTurn(withMove move: String) -> BattleTurnResult? {
        guard currentPokemonIndex < selectedTeam.count && currentOpponentIndex < opponentTeam.count else {
            battleResult = .playerWon
            battleState = .finished
            return nil
        }
        
        let player = selectedTeam[currentPokemonIndex]
        let opponent = opponentTeam[currentOpponentIndex]
        
        // Player attacks
        let playerDamage = calculateDamage(attacker: player, defender: opponent)
        opponentHP -= playerDamage
        
        var opponentMove = ""
        var opponentDamage = 0
        
        if opponentHP <= 0 {
            currentOpponentIndex += 1
            if currentOpponentIndex < opponentTeam.count {
                opponentHP = opponentTeam[currentOpponentIndex].hp
            } else {
                battleResult = .playerWon
                battleState = .finished
                return BattleTurnResult(playerDamage: playerDamage, opponentDamage: 0, opponentMove: "")
            }
        }
        
        // Opponent attacks
        if let opponent = opponentTeam[safe: currentOpponentIndex] {
            opponentMove = opponent.moves.first ?? "Attack"
            opponentDamage = calculateDamage(attacker: opponent, defender: player)
            playerHP -= opponentDamage
            
            if playerHP <= 0 {
                currentPokemonIndex += 1
                if currentPokemonIndex < selectedTeam.count {
                    playerHP = selectedTeam[currentPokemonIndex].hp
                } else {
                    battleResult = .opponentWon
                    battleState = .finished
                }
            }
        }
        
        return BattleTurnResult(
            playerDamage: playerDamage,
            opponentDamage: opponentDamage,
            opponentMove: opponentMove
        )
    }
    
    func calculateDamage(attacker: Pokemon, defender: Pokemon) -> Int {
        let attackStat = attacker.attack
        let defenseStat = defender.defense
        
        let baseDamage = Double(attackStat) / Double(defenseStat) * 20.0
        let randomFactor = Double.random(in: 0.85...1.15)
        
        return Int(baseDamage * randomFactor)
    }
    
    func resetBattle() {
        selectedTeam = []
        opponentTeam = []
        battleResult = nil
        battleState = .selectingTeam
        currentPokemonIndex = 0
        currentOpponentIndex = 0
        playerHP = 100
        opponentHP = 100
    }
    
    func switchPokemon(to index: Int) {
        guard index < selectedTeam.count && index != currentPokemonIndex else { return }
        
        // Switch to the new Pokemon
        currentPokemonIndex = index
        playerHP = selectedTeam[index].hp
        
        // Let opponent attack after switching
        if let opponent = opponentTeam[safe: currentOpponentIndex] {
            let opponentDamage = calculateDamage(attacker: opponent, defender: selectedTeam[currentPokemonIndex])
            playerHP -= opponentDamage
            
            // Check if the switched Pokemon fainted
            if playerHP <= 0 {
                currentPokemonIndex += 1
                if currentPokemonIndex < selectedTeam.count {
                    playerHP = selectedTeam[currentPokemonIndex].hp
                } else {
                    battleResult = .opponentWon
                    battleState = .finished
                }
            }
        }
    }
} 
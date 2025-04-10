import SwiftUI

struct BattleView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    @State private var battleMessage: String = ""
    
    var body: some View {
        VStack {
            // Opponent Pokemon
            if viewModel.currentOpponentIndex < viewModel.opponentTeam.count {
                PokemonBattleCard(
                    pokemon: viewModel.opponentTeam[viewModel.currentOpponentIndex],
                    health: viewModel.opponentHP,
                    isOpponent: true
                )
            }
            
            Spacer()
            
            // Battle Message
            if !battleMessage.isEmpty {
                Text(battleMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .transition(.opacity)
            }
            
            // Battle Status
            if let result = viewModel.battleResult {
                VStack {
                    Text(resultMessage(for: result))
                        .font(.title)
                        .bold()
                    
                    Button("Play Again") {
                        viewModel.resetBattle()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else {
                VStack(spacing: 20) {
                    Text("Battle in Progress!")
                        .font(.headline)
                    
                    Text("Your Pokemon: \(viewModel.currentPokemonIndex + 1)/\(viewModel.selectedTeam.count)")
                        .font(.subheadline)
                    
                    Text("Opponent Pokemon: \(viewModel.currentOpponentIndex + 1)/\(viewModel.opponentTeam.count)")
                        .font(.subheadline)
                    
                    Button("Attack!") {
                        if let currentPokemon = viewModel.selectedTeam[safe: viewModel.currentPokemonIndex],
                           let move = currentPokemon.moves.first {
                            if let turnResult = viewModel.performBattleTurn(withMove: move) {
                                battleMessage = "\(currentPokemon.name.capitalized) used \(move.capitalized)!\nDealt \(turnResult.playerDamage) damage!"
                                
                                if let opponent = viewModel.opponentTeam[safe: viewModel.currentOpponentIndex] {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        battleMessage = "\(opponent.name.capitalized) used \(turnResult.opponentMove.capitalized)!\nDealt \(turnResult.opponentDamage) damage!"
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.battleState != .battling)
                }
            }
            
            Spacer()
            
            // Player Pokemon
            if viewModel.currentPokemonIndex < viewModel.selectedTeam.count {
                PokemonBattleCard(
                    pokemon: viewModel.selectedTeam[viewModel.currentPokemonIndex],
                    health: viewModel.playerHP,
                    isOpponent: false
                )
            }
        }
        .padding()
        .navigationTitle("Battle!")
    }
    
    private func resultMessage(for result: BattleResult) -> String {
        switch result {
        case .playerWon:
            return "You Won! 🎉"
        case .opponentWon:
            return "You Lost! 😢"
        case .inProgress:
            return "Battle in Progress!"
        }
    }
}

struct PokemonBattleCard: View {
    let pokemon: Pokemon
    let health: Int
    let isOpponent: Bool
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(pokemon.id).png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 120, height: 120)
            
            Text(pokemon.name.capitalized)
                .font(.title2)
                .bold()
            
            HStack {
                Text("HP: \(health)/\(pokemon.hp)")
                    .font(.headline)
                
                ProgressView(value: Double(health), total: Double(pokemon.hp))
                    .frame(width: 100)
            }
            
            HStack(spacing: 20) {
                StatView(label: "ATK", value: pokemon.attack)
                StatView(label: "DEF", value: pokemon.defense)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(15)
    }
}

struct StatView: View {
    let label: String
    let value: Int
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
            Text("\(value)")
                .font(.headline)
        }
    }
} 
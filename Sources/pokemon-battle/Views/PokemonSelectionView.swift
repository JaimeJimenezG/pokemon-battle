import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PokemonSelectionView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            Group {
                switch viewModel.battleState {
                case .selectingTeam:
                    // First stack - Team Selection
                    TeamSelectionStack(viewModel: viewModel)
                case .battling:
                    // Second stack - Battle
                    BattleStack(viewModel: viewModel)
                case .finished:
                    // Third stack - Results
                    BattleResultsStack(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Group {
                    #if os(macOS)
                    Color(NSColor.windowBackgroundColor)
                    #else
                    Color(UIColor.systemBackground)
                    #endif
                }
            )
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        #if os(macOS)
        .frame(minWidth: 1200, minHeight: 800)
        .navigationViewStyle(.automatic)
        #endif
    }
}

// First Stack - Team Selection
struct TeamSelectionStack: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            #if DEBUG
            DebugInfoView(viewModel: viewModel)
            #endif
            
            // Selected Team Grid
            SelectedTeamGridView(viewModel: viewModel)
            
            if viewModel.isTeamFull {
                Button("Start Battle!") {
                    viewModel.battleState = .battling
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical, 4)
            }
            
            // Search Box
            SearchBoxView(viewModel: viewModel)
            
            // Available Pokemon Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100, maximum: 120)),
                    GridItem(.adaptive(minimum: 100, maximum: 120)),
                    GridItem(.adaptive(minimum: 100, maximum: 120)),
                    GridItem(.adaptive(minimum: 100, maximum: 120)),
                    GridItem(.adaptive(minimum: 100, maximum: 120))
                ], spacing: 16) {
                    ForEach(viewModel.filteredPokemons) { pokemon in
                        Button(action: {
                            Task {
                                await viewModel.selectPokemon(id: pokemon.id)
                            }
                        }) {
                            PokemonCard(
                                pokemon: pokemon,
                                isLoading: viewModel.loadingPokemonId == pokemon.id
                            )
                        }
                        .buttonStyle(.plain)
                        .opacity(viewModel.isTeamFull ? 0.5 : 1.0)
                        .disabled(viewModel.isTeamFull)
                    }
                }
                .padding()
            }
        }
        .padding()
        .task {
            await viewModel.loadPokemons()
        }
        .overlay {
            if viewModel.showErrorPopup, let errorMessage = viewModel.errorMessage {
                ErrorPopupView(message: errorMessage) {
                    viewModel.clearError()
                }
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.showErrorPopup)
            }
        }
    }
}

// Second Stack - Battle
struct BattleStack: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    @State private var showingAbilities = false
    @State private var showingSwitchPokemon = false
    @State private var showingItems = false
    @State private var battleMessage: String = ""
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Battle in Progress!")
                .font(.title)
                .frame(maxWidth: .infinity)
            
            // Opponent Pokemon
            if viewModel.currentOpponentIndex < viewModel.opponentTeam.count,
               let opponentPokemon = viewModel.opponentTeam[safe: viewModel.currentOpponentIndex] {
                PokemonBattleCard(
                    pokemon: opponentPokemon,
                    health: viewModel.opponentHP,
                    isOpponent: true
                )
            }
            
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
            
            // Battle Actions
            HStack(spacing: 20) {
                Button("Attack") {
                    showingAbilities = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Switch") {
                    showingSwitchPokemon = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Items") {
                    showingItems = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            // Your Pokemon
            if viewModel.currentPokemonIndex < viewModel.selectedTeam.count,
               let currentPokemon = viewModel.selectedTeam[safe: viewModel.currentPokemonIndex] {
                PokemonBattleCard(
                    pokemon: currentPokemon,
                    health: viewModel.playerHP,
                    isOpponent: false
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            Group {
                #if os(macOS)
                Color(NSColor.windowBackgroundColor)
                #else
                Color(UIColor.systemBackground)
                #endif
            }
        )
        .sheet(isPresented: $showingAbilities) {
            AbilitiesView(viewModel: viewModel, battleMessage: $battleMessage)
        }
        .sheet(isPresented: $showingSwitchPokemon) {
            SwitchPokemonView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingItems) {
            ItemsView(viewModel: viewModel)
        }
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct AbilitiesView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    @Binding var battleMessage: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            if viewModel.currentPokemonIndex < viewModel.selectedTeam.count,
               let currentPokemon = viewModel.selectedTeam[safe: viewModel.currentPokemonIndex] {
                List {
                    Section(header: Text("Moves")) {
                        ForEach(currentPokemon.moves.prefix(4), id: \.self) { move in
                            Button(action: {
                                // Handle move use with feedback
                                if let result = viewModel.performBattleTurn(withMove: move) {
                                    battleMessage = "\(currentPokemon.name.capitalized) used \(move.capitalized)!\nDealt \(result.playerDamage) damage!"
                                    
                                    if let opponent = viewModel.opponentTeam[safe: viewModel.currentOpponentIndex] {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            battleMessage = "\(opponent.name.capitalized) used \(result.opponentMove.capitalized)!\nDealt \(result.opponentDamage) damage!"
                                        }
                                    }
                                }
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "burst.fill")
                                        .foregroundColor(.purple)
                                    Text(move.capitalized)
                                        .font(.headline)
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Abilities")) {
                        ForEach(currentPokemon.abilities.prefix(4), id: \.self) { ability in
                            Button(action: {
                                // Handle ability use with feedback
                                if let result = viewModel.performBattleTurn(withMove: ability) {
                                    battleMessage = "\(currentPokemon.name.capitalized) used \(ability.capitalized)!\nDealt \(result.playerDamage) damage!"
                                    
                                    if let opponent = viewModel.opponentTeam[safe: viewModel.currentOpponentIndex] {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            battleMessage = "\(opponent.name.capitalized) used \(result.opponentMove.capitalized)!\nDealt \(result.opponentDamage) damage!"
                                        }
                                    }
                                }
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.blue)
                                    Text(ability.capitalized)
                                        .font(.headline)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Choose Attack")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct SwitchPokemonView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedPokemon: Pokemon?
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.selectedTeam.enumerated()), id: \.element.id) { index, pokemon in
                    Button(action: {
                        selectedPokemon = pokemon
                        showingConfirmation = true
                    }) {
                        HStack {
                            AsyncImage(url: pokemon.spriteURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                            } placeholder: {
                                ProgressView()
                            }
                            
                            VStack(alignment: .leading) {
                                Text(pokemon.name.capitalized)
                                    .font(.headline)
                                Text("HP: \(pokemon.hp)/\(pokemon.hp)")
                                    .font(.subheadline)
                                    .foregroundColor(index == viewModel.currentPokemonIndex ? .gray : .primary)
                            }
                            
                            Spacer()
                            
                            if index == viewModel.currentPokemonIndex {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .disabled(index == viewModel.currentPokemonIndex)
                }
            }
            .navigationTitle("Switch Pokemon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Switch Pokemon?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {
                    selectedPokemon = nil
                }
                Button("Switch") {
                    if let selectedPokemon = selectedPokemon,
                       let index = viewModel.selectedTeam.firstIndex(where: { $0.id == selectedPokemon.id }) {
                        viewModel.switchPokemon(to: index)
                        dismiss()
                    }
                }
            } message: {
                if let pokemon = selectedPokemon {
                    Text("Do you want to switch to \(pokemon.name.capitalized)?")
                }
            }
        }
    }
}

struct ItemsView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    @Environment(\.dismiss) var dismiss
    
    let items = ["Potion", "Super Potion", "Hyper Potion", "Max Potion", "Revive"]
    
    var body: some View {
        NavigationView {
            List(items, id: \.self) { item in
                Button(action: {
                    // Handle item use
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "cross.case")
                            .foregroundColor(.green)
                        Text(item)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Use Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Third Stack - Results
struct BattleResultsStack: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Battle Results")
                .font(.largeTitle)
            
            Spacer()
            
            Button("New Battle") {
                viewModel.battleState = .selectingTeam
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(
            Group {
                #if os(macOS)
                Color(NSColor.windowBackgroundColor)
                #else
                Color(UIColor.systemBackground)
                #endif
            }
        )
    }
}

// Debug info component
struct DebugInfoView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Debug Info:")
                .font(.caption)
                .bold()
            Text("Available Pokemon: \(viewModel.availablePokemons.count)")
                .font(.caption)
            Text("Filtered Pokemon: \(viewModel.filteredPokemons.count)")
                .font(.caption)
            Text("Is Loading: \(viewModel.isLoading ? "Yes" : "No")")
                .font(.caption)
            Text("Search Text: \(viewModel.searchText)")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// Selected team grid component
struct SelectedTeamGridView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Top row (3 slots)
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    if index < viewModel.selectedTeam.count {
                        SelectedPokemonCard(pokemon: viewModel.selectedTeam[index]) {
                            viewModel.removePokemonFromTeam(at: index)
                        }
                    } else {
                        EmptyPokemonSlot()
                    }
                }
            }
            
            // Bottom row (2 slots)
            HStack(spacing: 8) {
                ForEach(3..<5) { index in
                    if index < viewModel.selectedTeam.count {
                        SelectedPokemonCard(pokemon: viewModel.selectedTeam[index]) {
                            viewModel.removePokemonFromTeam(at: index)
                        }
                    } else {
                        EmptyPokemonSlot()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// Search box component
struct SearchBoxView: View {
    @ObservedObject var viewModel: PokemonBattleViewModel
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search by name or ID", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
}

struct PokemonCard: View {
    let pokemon: SimplePokemon
    let isLoading: Bool
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(pokemon.id).png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 60, height: 60)
            .overlay {
                if isLoading {
                    Color.white.opacity(0.7)
                        .overlay {
                            ProgressView()
                        }
                }
            }
            
            Text(pokemon.name.capitalized)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
}

struct SelectedPokemonCard: View {
    let pokemon: Pokemon
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(pokemon.id).png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 50, height: 50)
            
            Text(pokemon.name.capitalized)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
        }
        .padding(4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct EmptyPokemonSlot: View {
    var body: some View {
        VStack {
            Image(systemName: "plus.circle")
                .font(.system(size: 24))
                .foregroundColor(.gray)
            
            Text("Empty")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// Error Popup View
struct ErrorPopupView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            // Error popup content
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                
                Text("Error")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                
                Button("OK") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)
            }
            .padding(30)
            .background(
                Group {
                    #if os(macOS)
                    Color(NSColor.windowBackgroundColor)
                    #else
                    Color(UIColor.systemBackground)
                    #endif
                }
            )
            .cornerRadius(15)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
        .zIndex(100) // Ensure the popup is always on top
    }
} 
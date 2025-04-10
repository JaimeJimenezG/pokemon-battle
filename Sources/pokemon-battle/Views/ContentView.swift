import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PokemonBattleViewModel()

    var body: some View {
        NavigationView {
            // ... existing code ...
        }
        .overlay {
            if viewModel.showErrorPopup, let errorMessage = viewModel.errorMessage {
                ErrorPopupView(message: errorMessage) {
                    viewModel.showErrorPopup = false
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 
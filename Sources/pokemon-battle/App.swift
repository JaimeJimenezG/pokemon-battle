import SwiftUI

@main
struct PokemonBattleApp: App {
    @StateObject private var viewModel = PokemonBattleViewModel()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                PokemonSelectionView(viewModel: viewModel)
            }
            #if os(iOS)
            .navigationViewStyle(.stack)
            #endif
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
        }
    }
}

#if os(iOS)
import UIKit

extension UIApplication {
    static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.pokemon-battle"
    }
}
#endif 
import ArgumentParser
import Foundation
import KujtoCore

struct RootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "root",
        abstract: "Print the Kujto package checkout path."
    )

    func run() {
        print(KujtoRoot.locate().path)
    }
}

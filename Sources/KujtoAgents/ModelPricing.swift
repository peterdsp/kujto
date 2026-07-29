import Foundation

/// Per-model token prices, in USD per million tokens.
///
/// Prices are data, not literals in a formula, because they change and because
/// a wrong number here is a wrong number in front of the user. An unknown model
/// yields no cost rather than a guess, so the UI can say "not priced" instead
/// of showing a confident figure derived from the wrong rate.
public struct ModelPricing: Sendable, Equatable {
    public struct Rate: Sendable, Equatable {
        /// USD per million input tokens.
        public var input: Double
        /// USD per million output tokens.
        public var output: Double
        /// Multiplier applied to the input rate for tokens served from cache.
        public var cacheReadMultiplier: Double
        /// Multiplier applied to the input rate for tokens written to cache.
        public var cacheWriteMultiplier: Double

        public init(input: Double, output: Double,
                    cacheReadMultiplier: Double = 0.1,
                    cacheWriteMultiplier: Double = 1.25) {
            self.input = input
            self.output = output
            self.cacheReadMultiplier = cacheReadMultiplier
            self.cacheWriteMultiplier = cacheWriteMultiplier
        }
    }

    /// Rates by model id.
    public var rates: [String: Rate]

    public init(rates: [String: Rate]) {
        self.rates = rates
    }

    /// The rate for a model id, matching on the longest configured prefix so a
    /// dated or suffixed variant still prices correctly.
    public func rate(for model: String) -> Rate? {
        if let exact = rates[model] { return exact }
        return rates
            .filter { model.hasPrefix($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value
    }

    /// Cost of one usage record, or nil when the model has no configured rate.
    public func cost(of usage: SessionUsage) -> Double? {
        guard let rate = rate(for: usage.model) else { return nil }
        let million = 1_000_000.0
        let input = Double(usage.inputTokens) / million * rate.input
        let output = Double(usage.outputTokens) / million * rate.output
        let cacheRead = Double(usage.cacheReadTokens) / million * rate.input * rate.cacheReadMultiplier
        let cacheWrite = Double(usage.cacheWriteTokens) / million * rate.input * rate.cacheWriteMultiplier
        return input + output + cacheRead + cacheWrite
    }

    /// Ships-with defaults. Keys are prefixes, so `claude-opus-5` also prices a
    /// suffixed variant of the same family.
    public static let builtIn = ModelPricing(rates: [
        "claude-fable-5": Rate(input: 10, output: 50),
        "claude-mythos-5": Rate(input: 10, output: 50),
        "claude-opus-5": Rate(input: 5, output: 25),
        "claude-opus-4": Rate(input: 5, output: 25),
        "claude-sonnet-5": Rate(input: 3, output: 15),
        "claude-sonnet-4": Rate(input: 3, output: 15),
        "claude-haiku-4": Rate(input: 1, output: 5),
    ])

    /// Loads overrides from `pricing.json` under the Kujto root, falling back to
    /// the built-in table. A price change is then a file edit, not a release.
    public static func load(root: URL) -> ModelPricing {
        let url = root.appendingPathComponent("pricing.json")
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: StoredRate].self, from: data) else {
            return builtIn
        }
        var rates = builtIn.rates
        for (model, stored) in raw {
            rates[model] = Rate(input: stored.input, output: stored.output,
                                cacheReadMultiplier: stored.cacheReadMultiplier ?? 0.1,
                                cacheWriteMultiplier: stored.cacheWriteMultiplier ?? 1.25)
        }
        return ModelPricing(rates: rates)
    }

    struct StoredRate: Codable {
        var input: Double
        var output: Double
        var cacheReadMultiplier: Double?
        var cacheWriteMultiplier: Double?
    }
}

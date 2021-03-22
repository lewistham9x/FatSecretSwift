public struct AutocompleteSuggestion: Decodable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case suggestion
    }
    
    public let suggestion: [String]
    
    public init(suggestion: [String]) {
        self.suggestion = suggestion
    }
}

public struct Autocomplete: Decodable {
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case suggestions
    }

    public let suggestions: [AutocompleteSuggestion]

    public init(suggestions: [AutocompleteSuggestion]) {
        self.suggestions = suggestions
    }
}

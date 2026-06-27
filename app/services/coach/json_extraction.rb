module Coach
  # Claude is asked to respond with raw JSON, but models sometimes wrap it in
  # ```json fences anyway — strip those defensively before parsing.
  module JsonExtraction
    def self.parse(text)
      cleaned = text.strip.sub(/\A```(json)?/, "").sub(/```\z/, "").strip
      JSON.parse(cleaned)
    rescue JSON::ParserError => e
      raise Coach::Client::Error, "Claude returned non-JSON content: #{e.message}"
    end
  end
end

module Coach
  class Client
    Error = Class.new(StandardError)

    ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages".freeze
    DEFAULT_MODEL = ENV.fetch("CLAUDE_MODEL", "claude-sonnet-4-6")

    def initialize(api_key)
      @api_key = api_key
    end

    # messages: [{ role: "user"|"assistant", content: "..." }, ...]
    def call(system:, messages:, max_tokens: 2000)
      response = connection.post do |req|
        req.body = {
          model: DEFAULT_MODEL,
          max_tokens: max_tokens,
          system: system,
          messages: messages
        }.to_json
      end

      unless response.success?
        raise Error, "Claude API error (#{response.status}): #{response.body}"
      end

      response.body.dig("content", 0, "text").to_s
    end

    private

    def connection
      @connection ||= Faraday.new(ANTHROPIC_API_URL) do |f|
        f.request :retry, max: 2, interval: 0.5, exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
        f.headers["x-api-key"] = @api_key
        f.headers["anthropic-version"] = "2023-06-01"
        f.headers["content-type"] = "application/json"
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end

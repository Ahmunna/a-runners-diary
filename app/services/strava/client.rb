module Strava
  class Client
    Error = Class.new(StandardError)

    AUTHORIZE_URL = "https://www.strava.com/oauth/authorize".freeze
    TOKEN_URL = "https://www.strava.com/oauth/token".freeze
    API_BASE_URL = "https://www.strava.com/api/v3".freeze

    def self.authorize_url(redirect_uri, state:)
      query = {
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        approval_prompt: "auto",
        scope: "activity:read_all",
        state: state
      }.to_query

      "#{AUTHORIZE_URL}?#{query}"
    end

    def self.exchange_code(code)
      response = Faraday.post(TOKEN_URL, {
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        grant_type: "authorization_code"
      })

      raise Error, "Strava token exchange failed (#{response.status}): #{response.body}" unless response.success?

      JSON.parse(response.body)
    end

    def self.client_id = ENV.fetch("STRAVA_CLIENT_ID")
    def self.client_secret = ENV.fetch("STRAVA_CLIENT_SECRET")

    def initialize(strava_connection)
      @connection = strava_connection
    end

    def fetch_activity(strava_activity_id)
      ensure_fresh_token!
      response = http.get("#{API_BASE_URL}/activities/#{strava_activity_id}")
      raise Error, "Strava activity fetch failed (#{response.status}): #{response.body}" unless response.success?

      JSON.parse(response.body)
    end

    private

    attr_reader :connection

    def ensure_fresh_token!
      return unless connection.expired?

      response = Faraday.post(TOKEN_URL, {
        client_id: self.class.client_id,
        client_secret: self.class.client_secret,
        grant_type: "refresh_token",
        refresh_token: connection.refresh_token
      })
      raise Error, "Strava token refresh failed (#{response.status}): #{response.body}" unless response.success?

      data = JSON.parse(response.body)
      connection.update!(
        access_token: data["access_token"],
        refresh_token: data["refresh_token"],
        expires_at: Time.at(data["expires_at"])
      )
    end

    def http
      Faraday.new do |f|
        f.headers["Authorization"] = "Bearer #{connection.access_token}"
        f.adapter Faraday.default_adapter
      end
    end
  end
end

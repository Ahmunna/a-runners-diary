module Strava
  # Strava allows exactly one push subscription per API application. This
  # checks whether it already exists before creating it, so it's safe to call
  # repeatedly (app boot, daily self-heal sweep) without ever erroring on a
  # duplicate.
  class EnsureWebhookSubscription
    PUSH_SUBSCRIPTIONS_URL = "https://www.strava.com/api/v3/push_subscriptions".freeze

    def self.call = new.call

    def call
      return :exists if existing_subscription_id.present?

      create_subscription
    end

    private

    def existing_subscription_id
      response = Faraday.get(PUSH_SUBSCRIPTIONS_URL, {
        client_id: Strava::Client.client_id,
        client_secret: Strava::Client.client_secret
      })
      raise Strava::Client::Error, "Strava subscription lookup failed (#{response.status}): #{response.body}" unless response.success?

      JSON.parse(response.body).first&.fetch("id", nil)
    end

    def create_subscription
      response = Faraday.post(PUSH_SUBSCRIPTIONS_URL, {
        client_id: Strava::Client.client_id,
        client_secret: Strava::Client.client_secret,
        callback_url: callback_url,
        verify_token: ENV.fetch("STRAVA_WEBHOOK_VERIFY_TOKEN")
      })
      raise Strava::Client::Error, "Strava subscription creation failed (#{response.status}): #{response.body}" unless response.success?

      :created
    end

    def callback_url
      "https://#{ENV.fetch('APP_HOST', 'a-runners-diary.fly.dev')}/strava/webhook"
    end
  end
end

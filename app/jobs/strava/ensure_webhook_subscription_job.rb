module Strava
  class EnsureWebhookSubscriptionJob < ApplicationJob
    queue_as :default

    def perform
      result = Strava::EnsureWebhookSubscription.call
      Rails.logger.info("[Strava] webhook subscription check: #{result}")
    end
  end
end

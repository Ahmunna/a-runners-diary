# Run once when the actual web server boots (not on rake tasks, console, or
# the release_command migration step) so the Strava push subscription gets
# created/verified without manual intervention. Runs async via Solid Queue —
# never blocks server boot, and is safe to run repeatedly since the service
# checks before creating.
Rails.application.config.after_initialize do
  if defined?(Rails::Server) && !Rails.env.test? && ENV["STRAVA_CLIENT_ID"].present?
    Strava::EnsureWebhookSubscriptionJob.perform_later
  end
end

# Sends a Web Push notification to every device a user has subscribed from.
# Free protocol (VAPID) — no APNs/FCM account or per-message cost. Silently
# drops dead subscriptions (expired or revoked browser endpoints) instead of
# raising, since that's an expected, routine occurrence, not an error.
class PushNotificationService
  VAPID = {
    subject: "mailto:support@a-runners-diary.fly.dev",
    public_key: ENV.fetch("VAPID_PUBLIC_KEY", nil),
    private_key: ENV.fetch("VAPID_PRIVATE_KEY", nil)
  }.freeze

  def self.notify(user, title:, body:)
    return if VAPID[:public_key].blank? || VAPID[:private_key].blank?

    user.push_subscriptions.find_each do |subscription|
      deliver(subscription, title: title, body: body)
    end
  end

  def self.deliver(subscription, title:, body:)
    WebPush.payload_send(
      message: { title: title, body: body }.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: VAPID.slice(:subject, :public_key, :private_key)
    )
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    subscription.destroy
  rescue StandardError => e
    # A push notification is a side effect, never the main job (program
    # generation, activity review) — one bad subscription must not take
    # down the rest of the notify loop or bubble up into the caller.
    Rails.logger.error("[PushNotificationService] delivery failed for subscription #{subscription.id}: #{e.class} #{e.message}")
  end
end

import { Controller } from "@hotwired/stimulus"

// Subscribes/unsubscribes this browser to Web Push. iOS Safari only supports
// push for a PWA that's been added to the home screen (no native install
// prompt like Android) — see the ios-nudge controller for that banner.
export default class extends Controller {
  static values = { vapidPublicKey: String }

  async connect() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.element.textContent = "Push not supported on this browser"
      this.element.disabled = true
      return
    }

    this.registration = await navigator.serviceWorker.register("/service-worker.js")
    const subscription = await this.registration.pushManager.getSubscription()
    this.render(!!subscription)
  }

  async toggle() {
    const existing = await this.registration.pushManager.getSubscription()
    existing ? await this.unsubscribe(existing) : await this.subscribe()
  }

  async subscribe() {
    const permission = await Notification.requestPermission()
    if (permission !== "granted") return

    const subscription = await this.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
    })

    const json = subscription.toJSON()
    await fetch("/push_subscriptions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth })
    })

    this.render(true)
  }

  async unsubscribe(subscription) {
    await fetch(`/push_subscriptions?endpoint=${encodeURIComponent(subscription.endpoint)}`, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken }
    })
    await subscription.unsubscribe()
    this.render(false)
  }

  render(subscribed) {
    this.element.textContent = subscribed ? "Notifications enabled — tap to disable" : "Enable notifications"
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)))
  }
}

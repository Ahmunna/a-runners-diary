import { Controller } from "@hotwired/stimulus"

// Drives the dashboard's "get the app" card. Installing to the home screen
// (installStep) is independent of push notifications being configured —
// iOS Safari only exposes the Push API once installed and opened from the
// home screen, but the install step itself is always relevant regardless
// of whether VAPID keys are set up server-side. Notification-specific
// states (enableStep/enabled/unsupported) only apply when a VAPID public
// key was actually injected into the page.
export default class extends Controller {
  static targets = ["installStep", "enableStep", "enabled", "installedNoPush", "unsupported"]
  static values = { vapidPublicKey: String }

  async connect() {
    const isIos = /iphone|ipad|ipod/.test(window.navigator.userAgent.toLowerCase())
    const isStandalone = window.navigator.standalone === true || window.matchMedia("(display-mode: standalone)").matches

    if (isIos && !isStandalone) {
      this.show(this.installStepTarget)
      return
    }

    if (!this.vapidPublicKeyValue) {
      // Nothing actionable to show: iOS users who already installed get a
      // confirmation; everyone else (desktop/Android, never asked to
      // install anything) just sees no card at all rather than a false
      // "you're installed" claim.
      if (isIos && isStandalone) {
        this.show(this.installedNoPushTarget)
      } else {
        this.element.classList.add("hidden")
      }
      return
    }

    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      this.show(this.unsupportedTarget)
      return
    }

    this.registration = await navigator.serviceWorker.register("/service-worker.js")
    const subscription = await this.registration.pushManager.getSubscription()
    this.show(subscription ? this.enabledTarget : this.enableStepTarget)
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
      headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
      body: JSON.stringify({ endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth })
    })

    this.show(this.enabledTarget)
  }

  async unsubscribe() {
    const subscription = await this.registration.pushManager.getSubscription()
    if (subscription) {
      await fetch(`/push_subscriptions?endpoint=${encodeURIComponent(subscription.endpoint)}`, {
        method: "DELETE",
        headers: { "X-CSRF-Token": this.csrfToken }
      })
      await subscription.unsubscribe()
    }
    this.show(this.enableStepTarget)
  }

  show(target) {
    for (const name of this.constructor.targets) {
      this[`${name}Target`].classList.add("hidden")
    }
    target.classList.remove("hidden")
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

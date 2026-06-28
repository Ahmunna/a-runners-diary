import { Controller } from "@hotwired/stimulus"

// iOS Safari has no install prompt like Android, and push notifications
// only work once the PWA has been added to the home screen. Nudge those
// users specifically — everyone else never sees this banner.
export default class extends Controller {
  connect() {
    const isIos = /iphone|ipad|ipod/.test(window.navigator.userAgent.toLowerCase())
    const isStandalone = window.navigator.standalone === true || window.matchMedia("(display-mode: standalone)").matches

    if (isIos && !isStandalone) {
      this.element.classList.remove("hidden")
    }
  }
}

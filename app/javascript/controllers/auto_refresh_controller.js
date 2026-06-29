import { Controller } from "@hotwired/stimulus"

// Attached only to banners that represent a transient "something is being
// generated in the background" state (e.g. waiting on the first
// Coach::GenerateProgram call). Once that finishes, the underlying
// condition becomes false and this banner — and this controller — simply
// isn't rendered anymore, so there's nothing to stop/clean up explicitly.
export default class extends Controller {
  static values = { interval: { type: Number, default: 4000 } }

  connect() {
    this.timer = setInterval(() => window.location.reload(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}

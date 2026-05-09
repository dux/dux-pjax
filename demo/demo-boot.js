// Bootstrap: install the global click handler once and wire the custom
// confirm modal as soon as the singleton component is registered.
window.addEventListener('DOMContentLoaded', () => {
  if (typeof Pjax === 'undefined') {
    console.warn('dux-pjax not loaded yet')
    return
  }

  Pjax.onDocumentClick()

  const wireConfirm = () => {
    if (window.DemoConfirm) {
      Pjax.confirm = (msg, node) => window.DemoConfirm.ask(msg, node)
    } else {
      requestAnimationFrame(wireConfirm)
    }
  }
  wireConfirm()
})

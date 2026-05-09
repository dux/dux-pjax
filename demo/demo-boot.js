// Bootstrap: install the global click handler once and wire the custom
// confirm modal as soon as the singleton component is registered.
window.addEventListener('DOMContentLoaded', () => {
  Pjax.onDocumentClick()
  Pjax.confirm = (msg, node) => window.DemoConfirm.ask(msg, node)
})

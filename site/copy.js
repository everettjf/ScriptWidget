// Copy only the visible command or prompt selected by the user.
for (const button of document.querySelectorAll('[data-copy]')) {
  button.addEventListener('click', async () => {
    const source = document.getElementById(button.dataset.copy);
    const status = button.closest('.copy-block')?.nextElementSibling;
    if (!source || !status) return;
    try {
      await navigator.clipboard.writeText(source.textContent);
      status.textContent = 'Copied. Paste it into your terminal or Agent.';
    } catch {
      status.textContent = 'Could not copy. Select the text above and copy it manually.';
    }
  });
}

// Form validation
document.addEventListener('DOMContentLoaded', function() {
    const form = document.querySelector('form');
    if (!form) return;

    form.addEventListener('submit', function(e) {
        const passwordField = document.getElementById('password1');
        const confirmPasswordField = document.getElementById('password2');

        if (passwordField && confirmPasswordField) {
            // Validasi form registrasi
            if (passwordField.value !== confirmPasswordField.value) {
                e.preventDefault();
                showError('Kata sandi tidak cocok');
                return;
            }

            if (passwordField.value.length < 8) {
                e.preventDefault();
                showError('Kata sandi minimal 8 karakter');
                return;
            }
        }
    });
});

// Show error message
function showError(message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.textContent = message;
    
    const submitButton = document.querySelector('.btn');
    submitButton.parentNode.insertBefore(errorDiv, submitButton);

    // Remove error message after 3 seconds
    setTimeout(() => {
        errorDiv.remove();
    }, 3000);
}

// Show/hide password
document.querySelectorAll('input[type="password"]').forEach(input => {
    const toggleButton = document.createElement('button');
    toggleButton.type = 'button';
    toggleButton.className = 'password-toggle';
    toggleButton.innerHTML = '👁️';
    toggleButton.style.position = 'absolute';
    toggleButton.style.right = '10px';
    toggleButton.style.top = '50%';
    toggleButton.style.transform = 'translateY(-50%)';
    toggleButton.style.background = 'none';
    toggleButton.style.border = 'none';
    toggleButton.style.cursor = 'pointer';
    toggleButton.style.color = '#666';

    const wrapper = document.createElement('div');
    wrapper.style.position = 'relative';
    input.parentNode.insertBefore(wrapper, input);
    wrapper.appendChild(input);
    wrapper.appendChild(toggleButton);

    toggleButton.addEventListener('click', () => {
        input.type = input.type === 'password' ? 'text' : 'password';
    });
});
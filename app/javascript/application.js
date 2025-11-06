// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Cookie input helper
document.addEventListener('DOMContentLoaded', function() {
  const cookieInput = document.querySelector('.cookie-input');
  
  if (cookieInput) {
    // Auto-resize the textarea based on content
    cookieInput.addEventListener('input', function() {
      this.style.height = 'auto';
      this.style.height = Math.max(100, this.scrollHeight) + 'px';
    });
    
    // Add helpful behavior for paste events
    cookieInput.addEventListener('paste', function(e) {
      setTimeout(() => {
        // Clean up the pasted content by removing extra whitespace
        const cleanedValue = this.value.trim().replace(/\s+/g, ' ');
        if (cleanedValue !== this.value) {
          this.value = cleanedValue;
        }
        
        // Trigger resize
        this.style.height = 'auto';
        this.style.height = Math.max(100, this.scrollHeight) + 'px';
      }, 0);
    });
  }
});

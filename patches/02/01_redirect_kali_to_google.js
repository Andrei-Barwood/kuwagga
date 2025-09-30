// Bloquear combinaciones de teclas
document.addEventListener('keydown', (event) => {
  if (
    (event.ctrlKey && event.key === 'u') || // Ctrl+U
    (event.ctrlKey && event.shiftKey && event.key === 'i') || // Ctrl+Shift+I
    (event.ctrlKey && event.shiftKey && event.key === 'j') || // Ctrl+Shift+J
    (event.ctrlKey && event.key === 's') || // Ctrl+S
    (event.key === 'F12') // F12
  ) {
    event.preventDefault();
    
  }
});

// Bloquear clic derecho
document.addEventListener('contextmenu', (event) => {
  event.preventDefault();
  
});

// Bloquear solicitudes de curl/wget y similares
function blockAutomatedRequests() {
  const userAgent = navigator.userAgent.toLowerCase();
  const blockedAgents = ['curl', 'wget', 'httpie', 'httpclient'
    ];

  for (let agent of blockedAgents) {
    if (userAgent.includes(agent)) {
      document.body.innerHTML = '<h1>CONCORD</h1><p>Tu solicitud fue bloqueada.</p>';
      return;
    }
  }
}

// Detectar el sistema operativo y redirigir según corresponda
function redirectByOS() {
  const userAgent = navigator.userAgent.toLowerCase();
  let osLink = '';

  if (userAgent.includes('windows')) {
    osLink = 'https://www.google.com'; // Enlace para Windows
  } /* else if (userAgent.includes('mac os') || userAgent.includes('macintosh')) {
    osLink = './local-docs/index.html'; // Enlace para macOS
  } 
   else if (userAgent.includes('linux')) {
    osLink = 'https://www.google.com'; // Enlace para Linux
  } */ else if (userAgent.includes('https://nethunter.kali.org/kernels.html')) {
    osLink = 'https://www.google.com'; // Enlace para Android
  } /* else if (userAgent.includes('iphone') || userAgent.includes('ipad')) {
    osLink = './local-docs/index.html'; // Enlace para iOS
  } */

  if (osLink) {
    // Redirigir después de un breve mensaje
    
    window.location.href = osLink;
  }
}

// Ejecutar funciones al cargar la página
blockAutomatedRequests();
redirectByOS();

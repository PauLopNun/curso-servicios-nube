const DEMO_USERS = [
  { email: 'alumno@instituto.es', password: 'Alumno123!' }
];

const form    = document.getElementById('loginForm');
const emailEl = document.getElementById('email');
const pwdEl   = document.getElementById('password');
const formMsg = document.getElementById('formMsg');

function validate() {
  let valid = true;
  const emailErr = document.getElementById('emailError');
  const pwdErr   = document.getElementById('pwdError');
  emailErr.textContent = '';
  pwdErr.textContent   = '';
  if (!emailEl.value.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
    emailErr.textContent = 'Introduce un correo válido.';
    valid = false;
  }
  if (pwdEl.value.length < 8) {
    pwdErr.textContent = 'La contraseña debe tener mínimo 8 caracteres.';
    valid = false;
  }
  return valid;
}

form.addEventListener('submit', (e) => {
  e.preventDefault();
  if (!validate()) return;
  const user = DEMO_USERS.find(
    u => u.email === emailEl.value && u.password === pwdEl.value
  );
  formMsg.textContent = user
    ? '✅ Acceso correcto. Bienvenido/a!'
    : '❌ Credenciales incorrectas.';
  formMsg.style.color = user ? 'green' : 'red';
});

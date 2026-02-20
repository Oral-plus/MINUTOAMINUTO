<?php
require_once 'config.php';
if (isLoggedIn()) {
    header('Location: dashboard.php');
    exit;
}
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $user = trim($_POST['user'] ?? '');
    $pass = $_POST['pass'] ?? '';
    if ($user === ADMIN_USER && $pass === ADMIN_PASS) {
        $_SESSION['admin_logged'] = true;
        header('Location: dashboard.php');
        exit;
    }
    $error = 'Usuario o contraseña incorrectos.';
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin - Minuto a Minuto</title>
    <meta name="theme-color" content="#0f766e">
    <link rel="stylesheet" href="assets/style.css">
</head>
<body class="login-page">
    <div class="login-box">
        <div class="logo">
            <img src="../assets/logo_oral_plus.png" alt="Oral-Plus" onerror="this.remove()">
            <span class="logo-text">MINUTO A MINUTO</span>
        </div>
        <h1>Portal Administrador</h1>
        <?php if ($error): ?>
            <p class="alert alert-error"><?= htmlspecialchars($error) ?></p>
        <?php endif; ?>
        <form method="post">
            <input type="text" name="user" placeholder="Usuario" required autofocus>
            <input type="password" name="pass" placeholder="Contraseña" required>
            <button type="submit">Entrar</button>
        </form>
        <p class="hint">Credenciales por defecto: admin / minuto2025</p>
    </div>
</body>
</html>

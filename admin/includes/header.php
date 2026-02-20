<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#0f172a">
    <title><?= htmlspecialchars($pageTitle ?? 'Admin') ?> - Minuto a Minuto</title>
    <link rel="stylesheet" href="assets/style.css">
</head>
<body>
<div class="layout">
<aside class="sidebar">
    <h2>Minuto a Minuto</h2>
    <nav class="sidebar-nav">
        <a href="dashboard.php" class="<?= ($currentPage ?? '') === 'dashboard' ? 'active' : '' ?>"><span class="nav-icon">📊</span> Dashboard</a>
        <a href="supervisores.php" class="<?= ($currentPage ?? '') === 'supervisores' ? 'active' : '' ?>"><span class="nav-icon">👥</span> Supervisores</a>
        <a href="vendedores.php" class="<?= ($currentPage ?? '') === 'vendedores' ? 'active' : '' ?>"><span class="nav-icon">🏪</span> Vendedores</a>
        <a href="llamadas.php" class="<?= ($currentPage ?? '') === 'llamadas' ? 'active' : '' ?>"><span class="nav-icon">📞</span> Llamadas</a>
    </nav>
    <a href="logout.php" class="logout"><span class="nav-icon">🚪</span> Cerrar sesión</a>
</aside>
<main class="main">

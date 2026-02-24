<?php
// No permitir acceso directo
if (basename($_SERVER['SCRIPT_FILENAME'] ?? '') === 'config.php') {
    http_response_code(403);
    exit('Acceso denegado');
}
session_start();
require_once __DIR__ . '/api_client.php';

// Credenciales del portal admin (cambiar en producción)
define('ADMIN_USER', getenv('ADMIN_USER') ?: 'admin');
define('ADMIN_PASS', getenv('ADMIN_PASS') ?: 'minuto2025');

function isLoggedIn() {
    return !empty($_SESSION['admin_logged']);
}

function requireLogin() {
    if (!isLoggedIn()) {
        header('Location: index.php');
        exit;
    }
}

function formatDate($val) {
    if ($val instanceof DateTime) return $val->format('Y-m-d');
    return $val;
}

function formatDateTime($val) {
    if ($val instanceof DateTime) return $val->format('Y-m-d H:i');
    return $val;
}

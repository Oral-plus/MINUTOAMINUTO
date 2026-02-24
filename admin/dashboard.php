<?php
require_once 'config.php';
requireLogin();
$pageTitle = 'Dashboard';
$currentPage = 'dashboard';

$stats = [
    'supervisores' => 0,
    'vendedores' => 0,
    'llamadas' => 0,
    'llamadas_hoy' => 0,
];
$dbError = null;
try {
    $stats['supervisores'] = count(apiGetSupervisores());
    $stats['vendedores'] = count(apiGetVendedores());
    $hoy = date('Y-m-d');
    $todas = apiGetLlamadas($hoy, $hoy);
    $stats['llamadas_hoy'] = count($todas);
    $stats['llamadas'] = count(apiGetLlamadas('2020-01-01', date('Y-m-d')));
} catch (Exception $e) {
    $dbError = $e->getMessage();
}
include 'includes/header.php';
?>
<div class="card">
    <h2>Panel de control</h2>
    <?php if (!empty($dbError)): ?>
        <p class="alert alert-error">Error al conectar con la API: <?= htmlspecialchars($dbError) ?></p>
    <?php else: ?>
    <div class="stats">
        <div class="stat"><span><?= $stats['supervisores'] ?></span><small>Supervisores</small></div>
        <div class="stat"><span><?= $stats['vendedores'] ?></span><small>Vendedores</small></div>
        <div class="stat"><span><?= $stats['llamadas'] ?></span><small>Llamadas totales</small></div>
        <div class="stat"><span><?= $stats['llamadas_hoy'] ?></span><small>Llamadas hoy</small></div>
    </div>
    <p class="text-muted">Usa el menú lateral para gestionar supervisores, vendedores y consultar el registro de llamadas.</p>
    <?php endif; ?>
</div>
<?php include 'includes/footer.php'; ?>

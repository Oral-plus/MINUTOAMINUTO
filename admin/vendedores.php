<?php
require_once 'config.php';
requireLogin();
$pageTitle = 'Vendedores';
$currentPage = 'vendedores';

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['_action'] ?? 'create';
    try {
        if ($action === 'create') {
            $body = [
                'id' => !empty($_POST['id']) ? $_POST['id'] : ('v_' . uniqid()),
                'nombre' => $_POST['nombre'],
                'codigo' => $_POST['codigo'],
                'zona' => $_POST['zona'],
                'coachId' => $_POST['coachId'],
                'geolocalizacionActiva' => (int)($_POST['geolocalizacionActiva'] ?? 0),
                'horaInicioJornada' => !empty($_POST['horaInicioJornada']) ? $_POST['horaInicioJornada'] : null,
                'presupuestoMensual' => (float)($_POST['presupuestoMensual'] ?? 0),
                'presupuestoDiario' => (float)($_POST['presupuestoDiario'] ?? 0),
            ];
            apiPostVendedor($body);
            $msg = 'Vendedor creado correctamente.';
        } elseif ($action === 'delete' && !empty($_POST['id'])) {
            apiDeleteVendedor($_POST['id']);
            $msg = 'Vendedor eliminado.';
        }
    } catch (Exception $e) {
        $msg = 'Error: ' . $e->getMessage();
    }
}

$vendedoresRaw = apiGetVendedores();
$supervisoresMap = [];
foreach (apiGetSupervisores() as $s) {
    $supervisoresMap[$s['id'] ?? ''] = $s['nombre'] ?? '';
}
foreach ($vendedoresRaw as &$v) {
    $v['coachNombre'] = $supervisoresMap[$v['coachId'] ?? ''] ?? $v['coachId'] ?? '-';
}
usort($vendedoresRaw, fn($a, $b) => strcmp($a['nombre'] ?? '', $b['nombre'] ?? ''));
$coaches = array_filter(apiGetSupervisores(), fn($s) => ($s['cargo'] ?? '') === 'coach');
usort($coaches, fn($a, $b) => strcmp($a['nombre'] ?? '', $b['nombre'] ?? ''));
include 'includes/header.php';
?>
<div class="card">
    <h2>Vendedores</h2>
    <?php if ($msg): ?><p class="alert <?= strpos($msg, 'Error') !== false ? 'alert-error' : 'alert-success' ?>"><?= htmlspecialchars($msg) ?></p><?php endif; ?>
    <form method="post" style="margin-bottom: 1.5rem;">
        <input type="hidden" name="_action" value="create">
        <div class="form-grid">
            <div class="form-group"><label>ID</label><input type="text" name="id" placeholder="v_xxx (opcional)"></div>
            <div class="form-group"><label>Nombre</label><input type="text" name="nombre" required></div>
            <div class="form-group"><label>Codigo</label><input type="text" name="codigo" required></div>
            <div class="form-group"><label>Zona</label><input type="text" name="zona" required></div>
            <div class="form-group"><label>Coach</label>
                <select name="coachId" required>
                    <option value="">-- Seleccionar --</option>
                    <?php foreach ($coaches as $c): ?><option value="<?= htmlspecialchars($c['id']) ?>"><?= htmlspecialchars($c['nombre']) ?></option><?php endforeach; ?>
                </select>
            </div>
            <div class="form-group"><label>Geo activa</label><select name="geolocalizacionActiva"><option value="0">No</option><option value="1">Si</option></select></div>
            <div class="form-group"><label>Presupuesto mensual</label><input type="number" step="0.01" name="presupuestoMensual" value="0"></div>
            <div class="form-group"><label>Presupuesto diario</label><input type="number" step="0.01" name="presupuestoDiario" value="0"></div>
        </div>
        <button type="submit" class="btn btn-primary">Agregar vendedor</button>
    </form>
    <div class="table-wrap">
        <table>
            <thead><tr><th>ID</th><th>Nombre</th><th>Codigo</th><th>Zona</th><th>Coach</th><th>Geo</th><th>Acciones</th></tr></thead>
            <tbody>
            <?php foreach ($vendedoresRaw as $v): ?>
                <tr>
                    <td><?= htmlspecialchars($v['id'] ?? '') ?></td>
                    <td><?= htmlspecialchars($v['nombre'] ?? '') ?></td>
                    <td><?= htmlspecialchars($v['codigo'] ?? '') ?></td>
                    <td><?= htmlspecialchars($v['zona'] ?? '') ?></td>
                    <td><?= htmlspecialchars($v['coachNombre'] ?? $v['coachId'] ?? '-') ?></td>
                    <td><?= ($v['geolocalizacionActiva'] ?? 0) ? 'Si' : 'No' ?></td>
                    <td class="actions">
                        <form method="post" style="display:inline;" onsubmit="return confirm('Eliminar?');">
                            <input type="hidden" name="_action" value="delete"><input type="hidden" name="id" value="<?= htmlspecialchars($v['id']) ?>">
                            <button type="submit" class="btn btn-danger btn-sm">Eliminar</button>
                        </form>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php include 'includes/footer.php'; ?>

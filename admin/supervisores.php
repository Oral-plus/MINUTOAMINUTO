<?php
require_once 'config.php';
requireLogin();
$pageTitle = 'Supervisores';
$currentPage = 'supervisores';

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['_action'] ?? 'create';
    try {
        if ($action === 'create') {
            $body = [
                'id' => !empty($_POST['id']) ? $_POST['id'] : ('s_' . uniqid()),
                'nombre' => $_POST['nombre'],
                'codigo' => $_POST['codigo'],
                'zona' => $_POST['zona'],
                'cargo' => $_POST['cargo'] ?? 'coach',
                'superiorId' => !empty($_POST['superiorId']) ? $_POST['superiorId'] : null,
                'subordinadosIds' => isset($_POST['subordinadosIds']) ? (is_array($_POST['subordinadosIds']) ? implode(',', $_POST['subordinadosIds']) : $_POST['subordinadosIds']) : '',
            ];
            apiPostSupervisor($body);
            $msg = 'Supervisor creado correctamente.';
        } elseif ($action === 'delete' && !empty($_POST['id'])) {
            apiDeleteSupervisor($_POST['id']);
            $msg = 'Supervisor eliminado.';
        }
    } catch (Exception $e) {
        $msg = 'Error: ' . $e->getMessage();
    }
}

$supervisoresRaw = apiGetSupervisores();
usort($supervisoresRaw, fn($a, $b) => strcmp($a['nombre'] ?? '', $b['nombre'] ?? ''));
include 'includes/header.php';
?>
<div class="card">
    <h2>Supervisores (Coach, KAM, Jefe)</h2>
    <?php if ($msg): ?><p class="alert <?= strpos($msg, 'Error') !== false ? 'alert-error' : 'alert-success' ?>"><?= htmlspecialchars($msg) ?></p><?php endif; ?>
    <form method="post" style="margin-bottom: 1.5rem;">
        <input type="hidden" name="_action" value="create">
        <div class="form-grid">
            <div class="form-group"><label>ID</label><input type="text" name="id" placeholder="s_xxx (opcional)"></div>
            <div class="form-group"><label>Nombre</label><input type="text" name="nombre" required></div>
            <div class="form-group"><label>Codigo</label><input type="text" name="codigo" required></div>
            <div class="form-group"><label>Zona</label><input type="text" name="zona" required></div>
            <div class="form-group"><label>Cargo</label>
                <select name="cargo"><option value="coach">Coach</option><option value="KAM">KAM</option><option value="Jefe">Jefe</option></select>
            </div>
            <div class="form-group"><label>Superior ID</label><input type="text" name="superiorId" placeholder="Opcional"></div>
        </div>
        <button type="submit" class="btn btn-primary">Agregar supervisor</button>
    </form>
    <div class="table-wrap">
        <table>
            <thead><tr><th>ID</th><th>Nombre</th><th>Codigo</th><th>Zona</th><th>Cargo</th><th>Superior</th><th>Acciones</th></tr></thead>
            <tbody>
            <?php foreach ($supervisoresRaw as $s): ?>
                <tr>
                    <td><?= htmlspecialchars($s['id'] ?? '') ?></td>
                    <td><?= htmlspecialchars($s['nombre'] ?? '') ?></td>
                    <td><?= htmlspecialchars($s['codigo'] ?? '') ?></td>
                    <td><?= htmlspecialchars($s['zona'] ?? '') ?></td>
                    <td><?= htmlspecialchars($s['cargo'] ?? '') ?></td>
                    <td><?= htmlspecialchars($s['superiorId'] ?? '-') ?></td>
                    <td class="actions">
                        <form method="post" style="display:inline;" onsubmit="return confirm('Eliminar?');">
                            <input type="hidden" name="_action" value="delete"><input type="hidden" name="id" value="<?= htmlspecialchars($s['id']) ?>">
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

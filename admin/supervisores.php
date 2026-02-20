<?php
require_once 'config.php';
requireLogin();
$pageTitle = 'Supervisores';
$currentPage = 'supervisores';
$conn = getDbConnection();

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['_action'] ?? 'create';
    try {
        if ($action === 'create') {
            $id = !empty($_POST['id']) ? $_POST['id'] : ('s_' . uniqid());
            $sub = isset($_POST['subordinadosIds']) ? (is_array($_POST['subordinadosIds']) ? implode(',', $_POST['subordinadosIds']) : $_POST['subordinadosIds']) : '';
            if ($conn instanceof PDO) {
                $stmt = $conn->prepare("INSERT INTO supervisores (id,nombre,codigo,zona,cargo,superiorId,subordinadosIds) VALUES (?,?,?,?,?,?,?)");
                $stmt->execute([$id, $_POST['nombre'], $_POST['codigo'], $_POST['zona'], $_POST['cargo'] ?? 'coach', !empty($_POST['superiorId']) ? $_POST['superiorId'] : null, $sub]);
            } else {
                sqlsrv_query($conn, "INSERT INTO supervisores (id,nombre,codigo,zona,cargo,superiorId,subordinadosIds) VALUES (?,?,?,?,?,?,?)", [$id, $_POST['nombre'], $_POST['codigo'], $_POST['zona'], $_POST['cargo'] ?? 'coach', !empty($_POST['superiorId']) ? $_POST['superiorId'] : null, $sub]);
            }
            $msg = 'Supervisor creado correctamente.';
        } elseif ($action === 'delete' && !empty($_POST['id'])) {
            if ($conn instanceof PDO) {
                $conn->prepare("DELETE FROM supervisores WHERE id = ?")->execute([$_POST['id']]);
            } else {
                sqlsrv_query($conn, "DELETE FROM supervisores WHERE id = ?", [$_POST['id']]);
            }
            $msg = 'Supervisor eliminado.';
        }
    } catch (Exception $e) {
        $msg = 'Error: ' . $e->getMessage();
    }
}

$supervisores = dbQuery($conn, "SELECT * FROM supervisores ORDER BY nombre");
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
            <?php foreach ($supervisores as $s): ?>
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

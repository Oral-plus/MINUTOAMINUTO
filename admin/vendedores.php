<?php
require_once 'config.php';
requireLogin();
$pageTitle = 'Vendedores';
$currentPage = 'vendedores';
$conn = getDbConnection();

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['_action'] ?? 'create';
    try {
        if ($action === 'create') {
            $id = !empty($_POST['id']) ? $_POST['id'] : ('v_' . uniqid());
            if ($conn instanceof PDO) {
                $stmt = $conn->prepare("INSERT INTO vendedores (id,nombre,codigo,zona,coachId,geolocalizacionActiva,horaInicioJornada,presupuestoMensual,presupuestoDiario) VALUES (?,?,?,?,?,?,?,?,?)");
                $stmt->execute([$id, $_POST['nombre'], $_POST['codigo'], $_POST['zona'], $_POST['coachId'], (int)($_POST['geolocalizacionActiva'] ?? 0), !empty($_POST['horaInicioJornada']) ? $_POST['horaInicioJornada'] : null, (float)($_POST['presupuestoMensual'] ?? 0), (float)($_POST['presupuestoDiario'] ?? 0)]);
            } else {
                sqlsrv_query($conn, "INSERT INTO vendedores (id,nombre,codigo,zona,coachId,geolocalizacionActiva,horaInicioJornada,presupuestoMensual,presupuestoDiario) VALUES (?,?,?,?,?,?,?,?,?)", [$id, $_POST['nombre'], $_POST['codigo'], $_POST['zona'], $_POST['coachId'], (int)($_POST['geolocalizacionActiva'] ?? 0), !empty($_POST['horaInicioJornada']) ? $_POST['horaInicioJornada'] : null, (float)($_POST['presupuestoMensual'] ?? 0), (float)($_POST['presupuestoDiario'] ?? 0)]);
            }
            $msg = 'Vendedor creado correctamente.';
        } elseif ($action === 'delete' && !empty($_POST['id'])) {
            if ($conn instanceof PDO) {
                $conn->prepare("DELETE FROM vendedores WHERE id = ?")->execute([$_POST['id']]);
            } else {
                sqlsrv_query($conn, "DELETE FROM vendedores WHERE id = ?", [$_POST['id']]);
            }
            $msg = 'Vendedor eliminado.';
        }
    } catch (Exception $e) {
        $msg = 'Error: ' . $e->getMessage();
    }
}

$vendedores = dbQuery($conn, "SELECT v.*, s.nombre as coachNombre FROM vendedores v LEFT JOIN supervisores s ON v.coachId = s.id ORDER BY v.nombre");
$coaches = dbQuery($conn, "SELECT id, nombre FROM supervisores WHERE cargo = 'coach' ORDER BY nombre");
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
            <?php foreach ($vendedores as $v): ?>
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

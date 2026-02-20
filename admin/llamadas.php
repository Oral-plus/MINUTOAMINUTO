<?php
require_once 'config.php';
requireLogin();
$pageTitle = 'Llamadas';
$currentPage = 'llamadas';
$conn = getDbConnection();

$desde = $_GET['desde'] ?? date('Y-m-d');
$hasta = $_GET['hasta'] ?? date('Y-m-d');
$zona = $_GET['zona'] ?? '';

$sql = "SELECT * FROM registro_llamadas WHERE fecha >= ? AND fecha <= ?";
$params = [$desde, $hasta];
if ($zona) { $sql .= " AND zona = ?"; $params[] = $zona; }
$sql .= " ORDER BY horaInicio DESC";

$llamadas = dbQuery($conn, $sql, $params);
$zonasRaw = dbQuery($conn, "SELECT DISTINCT zona FROM registro_llamadas WHERE zona IS NOT NULL AND zona != ''");
$zonas = array_values(array_unique(array_filter(array_column($zonasRaw, 'zona'))));
sort($zonas);
include 'includes/header.php';
?>
<div class="card">
    <h2>Registro de llamadas</h2>
    <form method="get" class="filter-bar">
        <div class="form-group"><label>Desde</label><input type="date" name="desde" value="<?= htmlspecialchars($desde) ?>"></div>
        <div class="form-group"><label>Hasta</label><input type="date" name="hasta" value="<?= htmlspecialchars($hasta) ?>"></div>
        <div class="form-group"><label>Zona</label>
            <select name="zona">
                <option value="">Todas</option>
                <?php foreach ($zonas as $z): ?><option value="<?= htmlspecialchars($z) ?>" <?= $zona === $z ? 'selected' : '' ?>><?= htmlspecialchars($z) ?></option><?php endforeach; ?>
            </select>
        </div>
        <button type="submit" class="btn btn-primary">Filtrar</button>
    </form>
    <div class="table-wrap">
        <table>
            <thead>
                <tr>
                    <th>Fecha</th><th>Hora</th><th>Duración</th><th>Tipo</th><th>Líder</th><th>Contactado</th><th>Zona</th>
                    <th>Clientes P/V</th><th>Venta</th><th>Recaudo</th><th>Audio</th><th>Transcripción</th>
                </tr>
            </thead>
            <tbody>
            <?php foreach ($llamadas as $l): 
                $ruta = trim($l['rutaGrabacion'] ?? '');
                $transc = trim($l['transcripcionTexto'] ?? '');
                $lid = $l['id'] ?? '';
                $audioUrl = null;
                if ($ruta !== '' && $lid !== '') {
                    if (strpos($ruta, 'http://') === 0 || strpos($ruta, 'https://') === 0) {
                        $audioUrl = $ruta;
                    } else {
                        $base = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');
                        $script = $_SERVER['SCRIPT_NAME'] ?? '/admin/llamadas.php';
                        $root = dirname(dirname($script));
                        $audioUrl = $base . rtrim($root, '/') . '/api/audio?id=' . urlencode($lid);
                    }
                }
            ?>
                <tr>
                    <td><?= htmlspecialchars($l['fecha'] ?? '') ?></td>
                    <td><?= htmlspecialchars(substr($l['horaInicio'] ?? '', 11, 5)) ?></td>
                    <td><?= $l['duracionMinutos'] ?? 0 ?> min</td>
                    <td><?= htmlspecialchars($l['tipoLlamada'] ?? '') ?></td>
                    <td><?= htmlspecialchars($l['nombreLider'] ?? '') ?></td>
                    <td><?= htmlspecialchars($l['nombreContactado'] ?? '') ?></td>
                    <td><?= htmlspecialchars($l['zona'] ?? '') ?></td>
                    <td><?= ($l['clientesProgramados'] ?? 0) ?> / <?= ($l['clientesVisitados'] ?? 0) ?></td>
                    <td><?= number_format((float)($l['ventaDia'] ?? 0), 2) ?></td>
                    <td><?= number_format((float)($l['recaudoDia'] ?? 0), 2) ?></td>
                    <td>
                        <?php if ($audioUrl): ?>
                            <audio controls preload="none" style="max-width:180px;height:36px;">
                                <source src="<?= htmlspecialchars($audioUrl) ?>" type="audio/mpeg">
                                <source src="<?= htmlspecialchars($audioUrl) ?>" type="audio/mp3">
                                Tu navegador no soporta audio.
                            </audio>
                        <?php else: ?>-<?php endif; ?>
                    </td>
                    <td style="max-width:280px;">
                        <?php if ($transc !== ''): ?>
                            <details>
                                <summary style="cursor:pointer;color:var(--primary);font-size:0.9rem;">Ver transcripción (Gemini)</summary>
                                <div class="transcripcion-texto"><?= nl2br(htmlspecialchars($transc)) ?></div>
                            </details>
                        <?php else: ?>
                            <span style="color:#94a3b8;">Sin transcripción</span>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <p class="table-footer">Total: <?= count($llamadas) ?> llamadas</p>
</div>
<?php include 'includes/footer.php'; ?>

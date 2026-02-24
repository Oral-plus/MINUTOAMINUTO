<?php
declare(strict_types=1);

function sendApiHeaders(): void
{
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
}

function jsonResponse($data, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
}

function getJsonInput(): array
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }

    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        $cached = [];
        return $cached;
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        $cached = [];
        return $cached;
    }

    $cached = $decoded;
    return $cached;
}

function startsWith(string $haystack, string $needle): bool
{
    if ($needle === '') {
        return true;
    }
    return strpos($haystack, $needle) === 0;
}

function resolveRouteSegments(): array
{
    $uriPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    $uriPath = is_string($uriPath) ? $uriPath : '/';

    $scriptName = str_replace('\\', '/', $_SERVER['SCRIPT_NAME'] ?? '');
    $scriptDir = rtrim(str_replace('\\', '/', dirname($scriptName)), '/');

    $path = $uriPath;
    if ($scriptDir !== '' && $scriptDir !== '/' && startsWith($path, $scriptDir)) {
        $path = substr($path, strlen($scriptDir));
    }

    if (startsWith($path, '/index.php')) {
        $path = substr($path, strlen('/index.php'));
    }

    $path = trim($path, '/');
    if ($path === '') {
        return [];
    }

    return explode('/', $path);
}

function requiredString(array $input, string $field): string
{
    $value = trim((string)($input[$field] ?? ''));
    if ($value === '') {
        throw new InvalidArgumentException("Campo requerido: $field");
    }
    return $value;
}

function optionalString(array $input, string $field, string $default = ''): string
{
    return isset($input[$field]) ? trim((string)$input[$field]) : $default;
}

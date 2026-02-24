<?php
/**
 * Cliente para la API REST Minuto a Minuto.
 * Usa la misma API que la app Flutter (https://minutoaminuto-1.onrender.com)
 */
if (basename($_SERVER['SCRIPT_FILENAME'] ?? '') === 'api_client.php') {
    http_response_code(403);
    exit('Acceso denegado');
}

define('API_BASE_URL', getenv('API_BASE_URL') ?: 'https://minutoaminuto-1.onrender.com');

function apiRequest($method, $path, $body = null) {
    $url = rtrim(API_BASE_URL, '/') . '/' . ltrim($path, '/');
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_TIMEOUT => 15,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Accept: application/json'],
        ]);
        if ($body !== null && in_array($method, ['POST', 'PATCH', 'PUT'])) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, is_string($body) ? $body : json_encode($body));
        }
        $resp = curl_exec($ch);
        $code = (int) (curl_getinfo($ch, CURLINFO_HTTP_CODE) ?: 0);
        if (curl_errno($ch)) {
            curl_close($ch);
            throw new Exception('No se pudo conectar con la API: ' . curl_error($ch));
        }
        curl_close($ch);
    } else {
        $opts = [
            'http' => [
                'method' => $method,
                'header' => "Content-Type: application/json\r\nAccept: application/json\r\n",
                'timeout' => 15,
                'ignore_errors' => true,
            ],
        ];
        if ($body !== null && in_array($method, ['POST', 'PATCH', 'PUT'])) {
            $opts['http']['content'] = is_string($body) ? $body : json_encode($body);
        }
        $ctx = stream_context_create($opts);
        $resp = @file_get_contents($url, false, $ctx);
        $code = 200;
        if (isset($http_response_header[0]) && preg_match('/HTTP\/\d\.\d\s+(\d+)/', $http_response_header[0], $m)) {
            $code = (int) $m[1];
        }
        if ($resp === false) {
            throw new Exception('No se pudo conectar con la API. Verifique allow_url_fopen o instale cURL.');
        }
    }
    $data = json_decode($resp, true);
    if ($code >= 400) {
        $msg = is_array($data) && isset($data['error']) ? $data['error'] : $resp;
        throw new Exception('API error ' . $code . ': ' . $msg);
    }
    return $data;
}

function apiGet($path) {
    return apiRequest('GET', $path);
}

function apiPost($path, $body) {
    return apiRequest('POST', $path, $body);
}

function apiDelete($path) {
    return apiRequest('DELETE', $path);
}

function apiGetVendedores() {
    $r = apiGet('vendedores');
    return is_array($r) ? $r : [];
}

function apiGetVendedor($id) {
    $r = apiGet("vendedores/$id");
    return $r;
}

function apiPostVendedor($data) {
    return apiPost('vendedores', $data);
}

function apiDeleteVendedor($id) {
    return apiDelete("vendedores/$id");
}

function apiGetSupervisores() {
    $r = apiGet('supervisores');
    return is_array($r) ? $r : [];
}

function apiGetSupervisor($id) {
    return apiGet("supervisores/$id");
}

function apiPostSupervisor($data) {
    return apiPost('supervisores', $data);
}

function apiDeleteSupervisor($id) {
    return apiDelete("supervisores/$id");
}

function apiGetLlamadas($desde, $hasta, $zona = null) {
    $q = "desde=$desde&hasta=$hasta";
    if ($zona) $q .= "&zona=" . urlencode($zona);
    $r = apiGet("llamadas?$q");
    return is_array($r) ? $r : [];
}

function apiTestConnection() {
    try {
        $r = apiGet('test');
        return isset($r['success']) && $r['success'];
    } catch (Exception $e) {
        return false;
    }
}

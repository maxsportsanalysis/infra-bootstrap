<?php
header('Content-Type: text/cloud-config');

// Path to inventory
$inventoryFile = __DIR__ . '/inventory.json';

// Load existing inventory
$inventory = [];
if (file_exists($inventoryFile)) {
    $inventory = json_decode(file_get_contents($inventoryFile), true);
}

// Read MAC from query
$mac = strtoupper($_GET['mac'] ?? '');
if (!$mac) {
    http_response_code(400);
    echo "# Missing MAC address\n";
    exit;
}

// Check if MAC already exists in inventory
if (!isset($inventory[$mac])) {
    // Generate deterministic hostname
    $shortMac = substr(str_replace(':','',$mac), -4);
    $hostname = "node-$shortMac";

    // Generate random password (hashed)
    $password = password_hash(bin2hex(random_bytes(8)), PASSWORD_BCRYPT);

    // Optional: generate SSH key
    $ssh_pub = ""; // leave empty or generate externally

    // Store in inventory
    $inventory[$mac] = [
        'hostname' => $hostname,
        'username' => 'mcilek',
        'password' => $password,
        'ssh_pub'  => $ssh_pub
    ];
    file_put_contents($inventoryFile, json_encode($inventory, JSON_PRETTY_PRINT));
}

// Retrieve node info
$node = $inventory[$mac];

// Output cloud-init YAML
echo "#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: {$node['hostname']}
    username: {$node['username']}
    password: {$node['password']}
  ssh:
    install-server: true
    authorized-keys:
      - {$node['ssh_pub']}
";
?>
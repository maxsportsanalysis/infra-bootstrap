<?php
  header("Content-Type: text/plain");

  // Get MAC from query parameter
  $mac = strtoupper($_GET['mac'] ?? '');
  if (!$mac) {
      http_response_code(400);
      echo "Missing MAC";
      exit;
  }

  $json_file = '/srv/pxe/mac_status.json';
  if (!file_exists($json_file)) {
      file_put_contents($json_file, "{}");
  }

  // Read and update JSON
  $data = json_decode(file_get_contents($json_file), true);
  $data[$mac] = 'installed';

  // Save JSON atomically
  file_put_contents($json_file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

  echo "MAC $mac marked as installed";
?>
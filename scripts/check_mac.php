<?php
  header("Content-Type: text/plain");

  // Get MAC from query parameter
  $mac = strtoupper($_GET['mac'] ?? '');
  if (!$mac) {
      http_response_code(400);
      echo "Missing MAC";
      exit;
  }

  // Path to JSON file
  $json_file = '/srv/pxe/mac_status.json';
  if (!file_exists($json_file)) {
      file_put_contents($json_file, "{}"); // create empty JSON if missing
  }

  // Read JSON
  $data = json_decode(file_get_contents($json_file), true);

  // Check MAC status
  if (isset($data[$mac]) && $data[$mac] === 'installed') {
      http_response_code(200); // Already installed
      exit;
  } else {
      http_response_code(404); // New machine
      exit;
  }
?>
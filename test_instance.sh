#!/bin/bash
cat <<EOF > /tmp/body.json
{
  "instanceName": "bodyharmony-suporte",
  "qrcode": true
}
EOF
curl -s -X POST https://crm-api.bodyharmony.tech/instance/create \
  -H 'apikey: f8d8b13d-5c17-4952-b8d1-12c5b3644917' \
  -H 'Content-Type: application/json' \
  -d @/tmp/body.json

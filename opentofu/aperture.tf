# Aperture Configuration Management via OpenTofu

resource "null_resource" "aperture_config" {
  triggers = {
    config_hash = filemd5("${path.module}/../aperture/config.json")
  }

  provisioner "local-exec" {
    command = "${path.module}/../scripts/apply-aperture.sh"
    environment = {
      APERTURE_HOST = "ai.bun-bull.ts.net"
    }
  }
}

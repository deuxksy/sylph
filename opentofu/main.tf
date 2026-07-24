provider "tailscale" {
  # TAILSCALE_OAUTH_CLIENT_ID / TAILSCALE_OAUTH_CLIENT_SECRET / TAILSCALE_TAILNET
  # env는 scripts/tofu.sh가 주입
}

resource "tailscale_acl" "acl" {
  acl = file("${path.module}/../policy.hujson")
}

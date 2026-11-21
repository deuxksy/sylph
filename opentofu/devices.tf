# tag-device.sh와의 역할 분리: 여기 선언된 디바이스는 이 resource가 tag의 유일한 owner.
# (tailscale_device_tags는 전체 tag set을 교체함)
data "tailscale_device" "projector" {
  hostname = "ADT-3"
}

resource "tailscale_device_tags" "projector" {
  device_id = data.tailscale_device.projector.node_id
  tags      = ["tag:projector"]
}

# crong의 Mac mini — OS hostname은 NBSP(U+00A0)를 포함("crong의 Mac mini")하므로
# Tailnet machine name으로 매칭
data "tailscale_device" "eve" {
  name = "eve.bun-bull.ts.net"
}

resource "tailscale_device_tags" "eve" {
  device_id = data.tailscale_device.eve.node_id
  tags      = ["tag:mac"]
}

# azc2004의 Windows 데스크톱 — ava와 동일 패턴
data "tailscale_device" "desktop_ntm6hbn" {
  hostname = "DESKTOP-NTM6HBN"
}

resource "tailscale_device_tags" "desktop_ntm6hbn" {
  device_id = data.tailscale_device.desktop_ntm6hbn.node_id
  tags      = ["tag:pc", "tag:windows"]
}

# ksymailing의 휴대폰 — ipad/iphone과 동일 패턴
data "tailscale_device" "s25" {
  hostname = "S25"
}

resource "tailscale_device_tags" "s25" {
  device_id = data.tailscale_device.s25.node_id
  tags      = ["tag:mobile"]
}

data "tailscale_device" "x13" {
  hostname = "X13"
}

resource "tailscale_device_tags" "x13" {
  device_id = data.tailscale_device.x13.node_id
  tags      = ["tag:mobile"]
}

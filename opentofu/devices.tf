# tag-device.sh와의 역할 분리: 여기 선언된 디바이스는 이 resource가 tag의 유일한 owner.
# (tailscale_device_tags는 전체 tag set을 교체함)
data "tailscale_device" "projector" {
  hostname = "ADT-3"
}

resource "tailscale_device_tags" "projector" {
  device_id = data.tailscale_device.projector.node_id
  tags      = ["tag:mobile", "tag:android"]
}

# iOS 기기 — iphone은 hostname이 일반명 "localhost"라 Tailnet machine name으로 매칭 (eve 패턴)
data "tailscale_device" "ipad" {
  hostname = "ipad"
}

resource "tailscale_device_tags" "ipad" {
  device_id = data.tailscale_device.ipad.node_id
  tags      = ["tag:mobile", "tag:ios"]
}

data "tailscale_device" "iphone" {
  name = "iphone.bun-bull.ts.net"
}

resource "tailscale_device_tags" "iphone" {
  device_id = data.tailscale_device.iphone.node_id
  tags      = ["tag:mobile", "tag:ios"]
}

data "tailscale_device" "eve_ssh_test" {
  name = "eve.bun-bull.ts.net"
}

resource "tailscale_device_tags" "eve_ssh_test" {
  depends_on = [tailscale_acl.acl]
  device_id  = data.tailscale_device.eve_ssh_test.node_id
  tags       = ["tag:mac", "tag:eve-ssh-test"]
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
  tags      = ["tag:mobile", "tag:android"]
}

data "tailscale_device" "x13" {
  hostname = "X13"
}

resource "tailscale_device_tags" "x13" {
  device_id = data.tailscale_device.x13.node_id
  tags      = ["tag:mobile", "tag:android"]
}

# OCI 인스턴스 — tag:linux는 이 tailnet에서 서버 역할 겸 OS 태그
data "tailscale_device" "lt" {
  hostname = "lt"
}

resource "tailscale_device_tags" "lt" {
  device_id = data.tailscale_device.lt.node_id
  tags      = ["tag:oci", "tag:linux"]
}

data "tailscale_device" "brla" {
  hostname = "brla"
}

resource "tailscale_device_tags" "brla" {
  device_id = data.tailscale_device.brla.node_id
  tags      = ["tag:oci", "tag:linux"]
}

data "tailscale_device" "girl" {
  hostname = "girl"
}

resource "tailscale_device_tags" "girl" {
  device_id = data.tailscale_device.girl.node_id
  tags      = ["tag:linux"]
}

data "tailscale_device" "walle" {
  hostname = "walle"
}

resource "tailscale_device_tags" "walle" {
  depends_on = [tailscale_acl.acl]
  device_id  = data.tailscale_device.walle.node_id
  tags       = ["tag:linux", "tag:walle-ssh-test"]
}

data "tailscale_device" "heritage" {
  hostname = "heritage"
}

resource "tailscale_device_tags" "heritage" {
  device_id = data.tailscale_device.heritage.node_id
  tags      = ["tag:linux"]
}

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

# ksymailing의 vLLM 학습/서빙 노드 — 무태그라 ssh 정책 dst 불일치, tag:linux로 편입
data "tailscale_device" "keco_train_02" {
  hostname = "keco-train-02"
}

resource "tailscale_device_tags" "keco_train_02" {
  device_id = data.tailscale_device.keco_train_02.node_id
  tags      = ["tag:linux", "tag:kyolim"]
}

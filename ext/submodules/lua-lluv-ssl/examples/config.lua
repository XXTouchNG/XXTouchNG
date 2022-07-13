return {
  protocol    = "sslv3",
  key         = "./certs/clientAkey.pem",
  certificate = "./certs/clientA.pem",
  cafile      = "./certs/rootA.pem",
  verify      = {"peer", "fail_if_no_peer_cert"},
  options     = {"all", "no_sslv2"},
}


group "default" {
  targets = ["v3_11-jammy"]
}

group "jammy" {
  targets = ["v3_8-jammy", "v3_9-jammy", "v3_10-jammy", "v3_11-jammy", "v3_12-jammy"]
}

group "slim-jammy" {
  targets = ["v3_8-slim-jammy", "v3_9-slim-jammy", "v3_10-slim-jammy", "v3_11-slim-jammy", "v3_12-slim-jammy"]
}

group "kinetic" {
  targets = ["v3_8-kinetic", "v3_9-kinetic", "v3_10-kinetic", "v3_11-kinetic", "v3_12-kinetic"]
}

group "slim-kinetic" {
  targets = ["v3_8-slim-kinetic", "v3_9-slim-kinetic", "v3_10-slim-kinetic", "v3_11-slim-kinetic", "v3_12-slim-kinetic"]
}

target "riscv" {
  platforms = ["linux/riscv64"]
}

target "v3_7-jammy" {
  inherits = ["riscv"]
  context  = "3.7/jammy/"
  tags     = ["docker.io/cartesi/python:3.7.17-jammy", "docker.io/cartesi/python:3.7-jammy"]
}

target "v3_7-slim-jammy" {
  inherits = ["riscv"]
  context  = "3.7/slim-jammy/"
  tags     = ["docker.io/cartesi/python:3.7.17-slim-jammy", "docker.io/cartesi/python:3.7-slim-jammy"]
}

target "v3_8-jammy" {
  inherits = ["riscv"]
  context  = "3.8/jammy/"
  tags     = ["docker.io/cartesi/python:3.8.17-jammy", "docker.io/cartesi/python:3.8-jammy"]
}

target "v3_8-slim-jammy" {
  inherits = ["riscv"]
  context  = "3.8/slim-jammy/"
  tags     = ["docker.io/cartesi/python:3.8.17-slim-jammy", "docker.io/cartesi/python:3.8-slim-jammy"]
}

target "v3_9-jammy" {
  inherits = ["riscv"]
  context  = "3.9/jammy/"
  tags     = ["docker.io/cartesi/python:3.9.17-jammy", "docker.io/cartesi/python:3.9-jammy"]
}

target "v3_9-slim-jammy" {
  inherits = ["riscv"]
  context  = "3.9/slim-jammy/"
  tags     = ["docker.io/cartesi/python:3.9.17-slim-jammy", "docker.io/cartesi/python:3.9-slim-jammy"]
}

target "v3_10-jammy" {
  inherits = ["riscv"]
  context  = "3.10/jammy/"
  tags     = ["docker.io/cartesi/python:3.10.12-jammy", "docker.io/cartesi/python:3.10-jammy"]
}

target "v3_10-slim-jammy" {
  inherits = ["riscv"]
  context  = "3.10/slim-jammy/"
  tags     = ["docker.io/cartesi/python:3.10.12-slim-jammy", "docker.io/cartesi/python:3.10-slim-jammy"]
}

target "v3_11-jammy" {
  inherits = ["riscv"]
  context  = "3.11/jammy/"
  tags     = ["docker.io/cartesi/python:3.11.4-jammy", "docker.io/cartesi/python:3.11-jammy", "docker.io/cartesi/python:3-jammy", "docker.io/cartesi/python:jammy"]
}

target "v3_11-slim-jammy" {
  inherits = ["riscv"]
  context  = "3.11/slim-jammy/"
  tags     = ["docker.io/cartesi/python:3.11.4-slim-jammy", "docker.io/cartesi/python:3.11-slim-jammy", "docker.io/cartesi/python:3-slim-jammy", "docker.io/cartesi/python:slim-jammy"]
}

target "v3_12-jammy" {
  inherits = ["riscv"]
  context  = "3.12-rc/jammy/"
  tags     = ["docker.io/cartesi/python:3.12.0rc1-jammy", "docker.io/cartesi/python:3.12-rc-jammy"]
}

target "v3_12-slim-jammy" {
  inherits = ["riscv"]
  context  = "3.12-rc/slim-jammy/"
  tags     = ["docker.io/cartesi/python:3.12.0rc1-slim-jammy", "docker.io/cartesi/python:3.12-rc-slim-jammy"]
}

target "v3_7-kinetic" {
  inherits = ["riscv"]
  context  = "3.7/kinetic/"
  tags     = ["docker.io/cartesi/python:3.7.17-kinetic", "docker.io/cartesi/python:3.7-kinetic"]
}

target "v3_7-slim-kinetic" {
  inherits = ["riscv"]
  context  = "3.7/slim-kinetic/"
  tags     = ["docker.io/cartesi/python:3.7.17-slim-kinetic", "docker.io/cartesi/python:3.7-slim-kinetic"]
}

target "v3_8-kinetic" {
  inherits = ["riscv"]
  context  = "3.8/kinetic/"
  tags     = ["docker.io/cartesi/python:3.8.17-kinetic", "docker.io/cartesi/python:3.8-kinetic"]
}

target "v3_8-slim-kinetic" {
  inherits = ["riscv"]
  context  = "3.8/slim-kinetic/"
  tags     = ["docker.io/cartesi/python:3.8.17-slim-kinetic", "docker.io/cartesi/python:3.8-slim-kinetic"]
}

target "v3_9-kinetic" {
  inherits = ["riscv"]
  context  = "3.9/kinetic/"
  tags     = ["docker.io/cartesi/python:3.9.17-kinetic", "docker.io/cartesi/python:3.9-kinetic"]
}

target "v3_9-slim-kinetic" {
  inherits = ["riscv"]
  context  = "3.9/slim-kinetic/"
  tags     = ["docker.io/cartesi/python:3.9.17-slim-kinetic", "docker.io/cartesi/python:3.9-slim-kinetic"]
}

target "v3_10-kinetic" {
  inherits = ["riscv"]
  context  = "3.10/kinetic/"
  tags     = ["docker.io/cartesi/python:3.10.12-kinetic", "docker.io/cartesi/python:3.10-kinetic"]
}

target "v3_10-slim-kinetic" {
  inherits = ["riscv"]
  context  = "3.10/slim-kinetic/"
  tags     = ["docker.io/cartesi/python:3.10.12-slim-kinetic", "docker.io/cartesi/python:3.10-slim-kinetic"]
}

target "v3_11-kinetic" {
  inherits = ["riscv"]
  context  = "3.11/kinetic/"
  tags     = ["docker.io/cartesi/python:3.11.4-kinetic", "docker.io/cartesi/python:3.11-kinetic", "docker.io/cartesi/python:3-kinetic", "docker.io/cartesi/python:kinetic"]
}

target "v3_11-slim-kinetic" {
  inherits = ["riscv"]
  context  = "3.11/slim-kinetic/"
  tags     = ["docker.io/cartesi/python:3.11.4-slim-kinetic", "docker.io/cartesi/python:3.11-slim-kinetic", "docker.io/cartesi/python:3-slim-kinetic", "docker.io/cartesi/python:slim-kinetic"]
}

target "v3_12-kinetic" {
  inherits = ["riscv"]
  context  = "3.12-rc/kinetic/"
  tags     = ["docker.io/cartesi/python:3.12.0rc1-kinetic", "docker.io/cartesi/python:3.12-rc-kinetic"]
}

target "v3_12-slim-kinetic" {
  inherits = ["riscv"]
  context  = "3.12-rc/slim-kinetic/"
  tags     = ["docker.io/cartesi/python:3.12.0rc1-slim-kinetic", "docker.io/cartesi/python:3.12-rc-slim-kinetic"]
}

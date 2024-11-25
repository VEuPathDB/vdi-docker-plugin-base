IMAGE_NAME := "veupathdb/vdi-plugin-base"

CONTAINER_CMD := $(shell if command -v podman 2>&1 >/dev/null; then echo podman; else echo docker; fi)

default:

build:
	@$(CONTAINER_CMD) build \
		-t $(IMAGE_NAME):latest \
		--build-arg=GITHUB_USERNAME=${GITHUB_USERNAME} \
		--build-arg=GITHUB_TOKEN=${GITHUB_TOKEN} \
		.

run:
	@docker run -it --rm $(IMAGE_NAME):latest bash

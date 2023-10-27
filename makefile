IMAGE_NAME := "veupathdb/vdi-plugin-base"

default:

build:
	@docker build \
		-t $(IMAGE_NAME):latest \
		--build-arg=GITHUB_USERNAME=${GITHUB_USERNAME} \
		--build-arg=GITHUB_TOKEN=${GITHUB_TOKEN} \
		.

run:
	@docker run -it --rm $(IMAGE_NAME):latest bash
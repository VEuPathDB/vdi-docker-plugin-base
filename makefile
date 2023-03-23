IMAGE_NAME := "veupathdb/vdi-plugin-handler-base"

default:

build:
	@docker build \
		-t $(IMAGE_NAME):latest \
		--build-arg=GITHUB_USERNAME=${GITHUB_USERNAME} \
		--build-arg=GITHUB_TOKEN=${GITHUB_TOKEN} \
		.

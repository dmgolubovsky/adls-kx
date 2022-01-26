all:	build


build:
	docker-compose build $(CACHE) adls
	(unset DOCKER_HOST; dlimg $$BUILD_HOST adls-kx)




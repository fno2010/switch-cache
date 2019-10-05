P4APP=p4app/p4app

all: run

prepare:
	if [ ! -d p4app ]; then \
		git clone -b rc-2.0.0 https://github.com/p4lang/p4app.git; \
	fi
	${P4APP} update

patch: prepare
	cd p4app
	git apply ../win-docker.patch

run: prepare
	${P4APP} run cache.p4app
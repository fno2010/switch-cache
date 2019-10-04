P4APP=p4app/p4app

all: run

prepare:
	git clone -b rc-2.0.0 https://github.com/p4lang/p4app.git
	${P4APP} update

run:
	${P4APP} run cache.p4app
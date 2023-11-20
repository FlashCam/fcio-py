VERSION:=$(shell python3 src/fcio/_version.py)

.PHONY: build clean install uninstall dev upload upload-test

all: build

clean:
	rm -r dist

distclean: clean
	 rm -rf subprojects/{bufio,tmio,fcio}

build:
	meson subprojects update
	python3 -m build

uninstall:
	python3 -m pip uninstall -y fcio

install:
	python3 -m pip install --force-reinstall dist/fcio-$(VERSION)-*.whl

dev:
	python3 -m pip install -e .

upload: build
	twine upload --verbose dist/*.tar.gz

upload-test: build
	twine upload --verbose --repository testpypi dist/fcio-$(VERSION).tar.gz
VERSION:=$(shell python3 tools/version_util.py)

.PHONY: build clean install uninstall dev upload upload-test docs

all: build

clean:
	@rm -r dist

distclean: clean
	 @rm -rf subprojects/{bufio,tmio,fcio}

update:
	@meson subprojects update

build:
	@python3 -m build

uninstall:
	@python3 -m pip uninstall -y fcio

install:
	@python3 -m pip install --force-reinstall dist/fcio-$(VERSION)-*.whl

docs:
	@cd docs && $(MAKE) clean && $(MAKE) html

dev:
	@python3 -m pip install -e .

upload: build
	twine upload --verbose dist/*.tar.gz

upload-test: build
	twine upload --verbose --repository testpypi dist/fcio-$(VERSION).tar.gz
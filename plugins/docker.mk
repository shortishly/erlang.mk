# Copyright (c) 2016, Peter Morgan <peter.james.morgan@gmail.com>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: docker-build docker-logs docker-run
.PHONY: docker-scratch-cp-dynamic-libs docker-scratch-cp-link-loader docker-scratch-cp-sh

# Configuration.
DOCKERFILE ?= $(CURDIR)/Dockerfile

# Core targets.

ifeq ($(IS_DEP),)
ifneq ($(wildcard $(DOCKERFILE)),)
ifneq ($(PLATFORM),darwin)
rel:: docker-build
endif
endif
endif

define docker_erlang_system_info_version.erl
	io:format("~s~n", [erlang:system_info(version)]),
	halt(0).
endef

DOCKER_SYSTEM_INFO_VERSION = `$(call erlang,$(call docker_erlang_system_info_version.erl))`


# Plugin-specific targets.

docker-scratch-cp-dynamic-libs:
	$(gen_verbose) for lib in $$(ldd $(RELX_OUTPUT_DIR)/$(RELX_RELEASE)/erts-*/bin/* $(RELX_OUTPUT_DIR)/$(RELX_RELEASE)/lib/*/priv/lib/* $$(which sh) 2>/dev/null|grep "=>"|awk '{print $$3}'|sort|uniq); do \
	    mkdir -p $$(dirname $(RELX_OUTPUT_DIR)/$(RELX_RELEASE)$$lib); \
	    cp -L $$lib $(RELX_OUTPUT_DIR)/$(RELX_RELEASE)$$lib; \
	done

docker-scratch-cp-link-loader:
	$(gen_verbose) mkdir -p $(RELX_OUTPUT_DIR)/$(RELX_RELEASE)/lib64 && cp /lib64/ld-linux*.so.* $(RELX_OUTPUT_DIR)/$(RELX_RELEASE)/lib64

docker-scratch-cp-sh:
	$(gen_verbose) cp /bin/sh $(RELX_OUTPUT_DIR)/$(RELX_RELEASE)/bin

docker-strip-erts-binaries:
	$(gen_verbose) for fat in $$(file _rel/*/erts-*/bin/*|grep "not stripped"|awk '{print $$1}'|cut -d: -f1); do \
		strip $$fat &>/dev/null; \
	done

docker-build: relx-rel docker-scratch-cp-dynamic-libs docker-scratch-cp-link-loader docker-scratch-cp-sh docker-strip-erts-binaries
	$(gen_verbose) docker build --build-arg REL_NAME=$(PROJECT)_release --build-arg ERTS_VSN=$(DOCKER_SYSTEM_INFO_VERSION) --quiet --tag $(RELX_RELEASE):$(PROJECT_VERSION) .

docker-rm:
	$(gen_verbose) docker rm -f $(RELX_RELEASE) &>/dev/null || exit 0

docker-run: docker-rm
	$(gen_verbose) docker run --name $(RELX_RELEASE) -d $(RELX_RELEASE):$(PROJECT_VERSION)

docker-logs:
	$(gen_verbose) docker logs $(RELX_RELEASE)

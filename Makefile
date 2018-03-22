.DEFAULT_GOAL := build

BASE_DIR ?= ${CURDIR}

IMAGE_TAG_NAME ?= "arkivum/nextcloud"
IMAGE_TAG_VERSION ?= "latest"

all: validate clean build

build: build-apps build-nextcloud-image

build-apps: build-files-move-app build-user-saml-app

build-files-move-app:
	# Build the 'files_mv' NextCloud app
	@mkdir -p "$(BASE_DIR)/build"
	@if [ ! -f build/files_mv/appinfo/info.xml ] ; then \
		docker run --rm \
			--volume "$(BASE_DIR)/src/:/src:ro" \
			--volume "$(BASE_DIR)/build:/build" \
			--workdir "/src/" \
			--env BUILD_OWNER=$(shell id -u):$(shell id -g) \
			python \
			./files_mv/build.sh ; \
	fi

build-user-saml-app:
	# Build the 'user_saml' NextCloud app
	@mkdir -p "$(BASE_DIR)/build"
	@if [ ! -f build/user_saml/appinfo/info.xml ] ; then \
		docker run --rm \
			--volume "$(BASE_DIR)/src/:/src:ro" \
			--volume "$(BASE_DIR)/build:/build" \
			--workdir "/src/" \
			--env BUILD_OWNER=$(shell id -u):$(shell id -g) \
			python \
			./user_saml/build.sh ; \
	fi

build-nextcloud-image:
	# Build NextCloud docker image
	@docker build -t "$(IMAGE_TAG_NAME):$(IMAGE_TAG_VERSION)" .

clean:
	# Remove build artefacts
	@rm -Rf "$(BASE_DIR)/build"

validate:
	# Run ShellCheck to validate shell scripts
	@mkdir -p build/reports/shellcheck
	@for f in $$(find . -type f -name \*.sh) ; do \
		echo "Validating '$${f}' ... " ; \
		report_file="build/reports/shellcheck/$$(echo $${f} | tr '/' '_').txt" ;\
		docker run --rm \
			-v $$(pwd):/scripts \
			--workdir /scripts \
			koalaman/shellcheck -x -f gcc \
				$${f} | tee $${report_file} ; \
		if [ -s $${report_file} ] ; then \
			errors=$$(grep error: $${report_file} | wc -l) ; \
			notes=$$(grep note: $${report_file} | wc -l) ; \
			warnings=$$(grep warning: $${report_file} | wc -l) ; \
			echo "Validation failed for '$${f}'. $${errors} error(s), $${warnings} warning(s), $${notes} note(s)" ; \
			return 1 ; \
		else \
			echo "Validated '$${f}', all OK." ;\
		fi ;\
	done

.PHONY: all build build-apps build-files-move-app build-user-saml-app build-nextcloud-image clean validate

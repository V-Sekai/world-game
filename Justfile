export RUST_LOG := "log"
export MVSQLITE_DATA_PLANE := "http://192.168.0.39:7000"
export OPERATING_SYSTEM := os()
export EDITOR_TYPE_COMMAND := "run-editor-$OPERATING_SYSTEM"
export PROJECT_PATH := "" # Can be empty

export BUILD_COUNT := "001"
export DOCKER_GOCDA_AGENT_CENTOS_8_GROUPS_GIT := "abcdefgh"  # Example hash
export GODOT_GROUPS_EDITOR_PIPELINE_DEPENDENCY := "dependency_name"

export LABEL_TEMPLATE := "docker-gocd-agent-centos-8-groups_${DOCKER_GOCDA_AGENT_CENTOS_8_GROUPS_GIT:0:8}.$BUILD_COUNT"
export GROUPS_LABEL_TEMPLATE := "groups-4.3.$GODOT_GROUPS_EDITOR_PIPELINE_DEPENDENCY.$BUILD_COUNT"
export GODOT_STATUS := "groups-4.3"
export GIT_URL_DOCKER := "https://github.com/V-Sekai/docker-groups.git"
export GIT_URL_VSEKAI := "https://github.com/V-Sekai/v-sekai-game.git"
export WORLD_PWD := invocation_directory()
export SCONS_CACHE := "/app/.scons_cache"

deploy_just_docker:
    set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]
    @just build_just_docker
    docker run -it --rm -v $WORLD_PWD:/app just-fedora-app

list_files:
    ls export_windows
    ls export_linuxbsd

deploy_game:
    echo "Deploying game binaries..."

copy_binaries:
    cp templates/windows_release_x86_64.exe export_windows/v_sekai_windows.exe
    cp templates/linux_release.x86_64 export_linuxbsd/v_sekai_linuxbsd

prepare_exports:
    rm -rf export_windows export_linuxbsd
    mkdir export_windows export_linuxbsd

generate_build_constants:
    echo "## AUTOGENERATED BY BUILD" > v/addons/vsk_version/build_constants.gd
    echo "" >> v/addons/vsk_version/build_constants.gd
    echo "const BUILD_LABEL = \"$GROUPS_LABEL_TEMPLATE\"" >> v/addons/vsk_version/build_constants.gd
    echo "const BUILD_DATE_STR = \"$(shell date --utc --iso=seconds)\"" >> v/addons/vsk_version/build_constants.gd
    echo "const BUILD_UNIX_TIME = $(shell date +%s)" >> v/addons/vsk_version/build_constants.gd

clone_repo_vsekai:
    if [ ! -d "v" ]; then \
        git clone $GIT_URL_VSEKAI v; \
    else \
        git -C v pull origin main; \
    fi

# push_docker:
#     set -x; \
#     docker push "groupsinfra/gocd-agent-centos-8-groups:$LABEL_TEMPLATE" && \
#     echo "groupsinfra/gocd-agent-centos-8-groups:$LABEL_TEMPLATE" > docker_image.txt

build_just_docker:
    docker build --platform linux/x86_64 -t just-fedora-app . --cache-from just-fedora-app:latest

deploy_osxcross:
    #!/usr/bin/env bash
    git clone https://github.com/tpoechtrager/osxcross.git || true
    cd osxcross
    ./tools/gen_sdk_package.sh 

build_docker:
    set -x; \
    docker build -t "groupsinfra/gocd-agent-centos-8-groups:$LABEL_TEMPLATE" "g/gocd-agent-centos-8-groups"

clone_repo:
    if [ ! -d "g" ]; then \
        git clone $GIT_URL_DOCKER g; \
    else \
        git -C g pull origin master; \
    fi

run-editor:
    @just build-all
    @just {{ EDITOR_TYPE_COMMAND }}

build-all:
    #!/usr/bin/env bash
    export PATH=/llvm-mingw-20240917-ucrt-ubuntu-20.04-x86_64/bin:$PATH
    export OSXCROSS_ROOT=/osxcross
    parallel --ungroup --jobs 2 '
        platform={1}
        target={2}
        cd godot
        case "$platform" in
            windows)
                EXTRA_FLAGS="use_mingw=yes use_llvm=yes"
                ;;
            mac)
                EXTRA_FLAGS="osxcross_sdk=darwin24 vulkan=no arch=$arch"
                ;;
            linux|android)
                EXTRA_FLAGS=""
                ;;
            web)
                EXTRA_FLAGS="threads=yes lto=none dlink_enabled=yes builtin_glslang=yes builtin_openxr=yes module_raycast_enabled=no module_speech_enabled=no javascript_eval=no"
                ;;
        esac        
        scons platform=$platform \
            linkflags="-Wl,-pdb=" \
            ccflags="-g -gcodeview" \
            use_thinlto=yes \
            werror=no \
            compiledb=yes \
            generate_bundle=yes \
            precision=double \
            target=$target \
            test=yes \
            debug_symbol=yes \
            $EXTRA_FLAGS
        case "$platform" in
            android)
                if [ "$target" = "editor" ]; then
                    cd platform/android/java
                    ./gradlew generateGodotEditor
                    ./gradlew generateGodotHorizonOSEditor
                    cd ../../..
                    ls -l bin/android_editor_builds/
                elif [ "$target" = "template_release" ] || [ "$target" = "template_debug" ]; then
                    cd platform/android/java
                    ./gradlew generateGodotTemplates
                    cd ../../..
                    ls -l bin/
                fi
                ;;
            macos)
                # Build the mac platform for arm64 so we can build universal macos builds.
                scons platform=$platform \
                    use_thinlto=yes \
                    werror=no \
                    compiledb=yes \
                    generate_bundle=yes \
                    precision=double \
                    target=$target \
                    test=yes \
                    debug_symbol=yes \
                    arch=arm64 \
                    $EXTRA_FLAGS
            web)
                cd bin
                files_to_delete=(
                    "*.wasm"
                    "*.js"
                    "*.html"
                    "*.worker.js"
                    "*.engine.js"
                    "*.service.worker.js"
                    "*.wrapped.js"
                )
                for file_pattern in "${files_to_delete[@]}"; do
                    echo "Deleting files: $file_pattern"
                    rm -f $file_pattern
                done
                cd ..
                ls -l bin/
                ;;            
        esac
    ' ::: windows android web linux macos \
    ::: editor
    # ::: editor template_release template_debug

build_vsekai:
    just clone_repo_vsekai generate_build_constants prepare_exports copy_binaries list_files

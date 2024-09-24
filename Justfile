export RUST_LOG := "log"
export MVSQLITE_DATA_PLANE := "http://192.168.0.39:7000"
export OPERATING_SYSTEM := os()
export ANDROID_HOME_COMMAND := "set-android-home-$OPERATING_SYSTEM"
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

set-android-home:
    @just {{ ANDROID_HOME_COMMAND }}

set-android-home-linux:
    export ANDROID_HOME="/usr/local/share/android-sdk"

set-android-home-windows:
    export ANDROID_HOME="C:/Users/ernest.lee/AppData/Local/Android/Sdk"

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

push_docker:
    set -x; \
    docker push "groupsinfra/gocd-agent-centos-8-groups:$LABEL_TEMPLATE" && \
    echo "groupsinfra/gocd-agent-centos-8-groups:$LABEL_TEMPLATE" > docker_image.txt

build_just_docker:
    docker build -t just-fedora-app .

deploy_just_docker:
    @just build_just_docker
    docker run -it --rm -v "$(pwd)":/app just-fedora-app

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
    @just build-godot
    @just {{ EDITOR_TYPE_COMMAND }}

build-godot-windows:
    @just build-godot-windows-editor
    @just build-godot-template-debug
    @just build-godot-template-release

build-godot-windows-editor:
    #!/usr/bin/env bash
    export PATH=/llvm-mingw-20240917-ucrt-ubuntu-20.04-aarch64/bin:$PATH
    cd godot 
    scons platform=windows \
        werror=no \
        compiledb=yes \
        dev_build=no \
        generate_bundle=no \
        precision=double \
        target=editor \
        tests=yes \
        debug_symbols=yes \
        LINKFLAGS='-Wl,-pdb=' \
        CCFLAGS='-g -gcodeview'

build-godot-windows-template-release:
    #!/usr/bin/env bash
    export PATH=/llvm-mingw-20240917-ucrt-ubuntu-20.04-aarch64/bin:$PATH
    cd godot 
    scons platform=windows \
        werror=no \
        compiledb=yes \
        dev_build=no \
        generate_bundle=yes \
        precision=double \
        target=template_release \
        tests=no \
        debug_symbols=no \
        LINKFLAGS='-Wl,-pdb=' \
        CCFLAGS='-g -gcodeview'

build-godot-windows-template-debug:
    #!/usr/bin/env bash
    export PATH=$(pwd)/llvm-mingw-20240917-ucrt-ubuntu-20.04-aarch64/bin:$PATH
    cd godot 
    scons platform=windows \
        werror=no \
        compiledb=yes \
        dev_build=no \
        generate_bundle=yes \
        precision=double \
        target=template_debug \
        tests=yes \
        debug_symbols=yes \
        LINKFLAGS='-Wl,-pdb=' \
        CCFLAGS='-g -gcodeview'

build-godot-macos-editor:
    #!/usr/bin/env bash
    export OSXCROSS_ROOT="/osxcross"
    cd godot 
    scons platform=macos \
    osxcross_sdk=darwin24 \
    werror=no \
    vulkan=no \
    compiledb=yes \
    dev_build=no \
    generate_bundle=no \
    precision=double \
    target=editor \
    tests=yes \
    arch=arm64 \
    debug_symbols=yes

build-godot-linux-editor:
    #!/usr/bin/env bash
    cd godot
    scons platform=linux \
    use_llvm=yes \
    werror=no \
    compiledb=yes \
    linker=mold \
    dev_build=no \
    generate_bundle=no \
    precision=double \
    target=editor \
    tests=yes \
    debug_symbols=yes

build-godot-web-template-release:
    #!/usr/bin/env bash
    cd godot 
    # Needs 59+ gigabytes of ram for the editor web build.
    scons platform=web \
    werror=no \
    compiledb=yes \
    threads=yes \
    linker=mold \
    dev_build=no \
    generate_bundle=no \
    precision=double \
    target=template_release \
    tests=yes \
    debug_symbols=yes \
    lto=none \
    dlink_enabled=yes \
    builtin_glslang=yes \
    builtin_openxr=yes \
    module_raycast_enabled=no \
    module_speech_enabled=no \
    javascript_eval=no

build-godot:
    #!/usr/bin/env -S parallel --shebang --ungroup --jobs {{ num_cpus() }}
    echo task windows start; just build-godot-windows; echo task windows done
    echo task macos-editor start; just build-godot-macos-editor; echo task macos-editor done
    echo task linux-editor start; just build-godot-linux-editor; echo task linux-editor done
    echo task web-template-release start; just build-godot-web-template-release; echo task web-template-release done

build-godot-local:
    #!/usr/bin/env bash
    cd godot 
    scons platform=macos \
    werror=no \
    vulkan=no \
    compiledb=yes \
    dev_build=no \
    generate_bundle=no \
    precision=double \
    target=editor \
    tests=yes \
    arch=arm64 \
    debug_symbols=yes

run-godot-local:
    @just build-godot-local
    ./godot/bin/godot.macos.editor.double.arm64 --path sandbox_demo -e

build_vsekai:
    just clone_repo_vsekai generate_build_constants prepare_exports copy_binaries list_files

deploy_vsekai:
    just deploy_game

full_build_deploy:
    just build_vsekai deploy_vsekai build_docker push_docker

default:
    @just --choose
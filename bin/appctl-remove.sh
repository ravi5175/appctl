#!/bin/bash

ERR_CODE_NOT_EXIST=1500
ERR_CODE_PERMISSION=1501
ERR_CODE_EXECUTION=1502
ERR_CODE_TYPE=1503
ERR_CODE_NOT_DEFINED=1504
ERR_CODE_INVALID_OPTION=1505

ERR_MESG() {
    echo "[Error]: $@"
}

INFO_MESG() {
    echo "[Info]: $@"
}

ERR_EXIT() {
    local err_code=$1
    shift
    cleanup
    ERR_MESG "$@"
    exit $err_code
}

function cleanup {
    [[ ! -z "$TEMP_DIR"  ]] && [[ -d "$TEMP_DIR"  ]] && rm -r "$TEMP_DIR"
    [[ ! -z "$LOCK_FILE" ]] && [[ -e "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f .data/info ]] && rm -r .data
    return 0
}

function IsInstalled {
    echo "$DATA_DIR/$1"
    [[ -f "$DATA_DIR/$1/info" ]] && return 0 || return 1    
}


trap "interrupted" 1 2 3 15

export LC_ALL=C

interrupted() {
    echo
    ERR_EXIT $ERR_CODE_EXECUTION ""
}

function PrintHelp {
cat << EOF
$(basename $0) - part os rlxOS appctl tool to remove installed applications

Usage $(basename $0) [ <options> ] <appname>

Options:
    -h, --help          print this help message
    -v, --verbose       verbosly print debug messages
        --skip-pre      skip the pre remove script
        --skip-post     skip the post remove script
        --root-dir=<path>   remove packages from custom root directory                
EOF
}

function Main {
    for i in $@ ; do
        case $i in
            -h| --help)
                PrintHelp
                exit 0
                ;;
            
            -v| --verbose)
                VERBOSE=1
                ;;
            
            --skip-pre)
                SKIP_PRE=1
                ;;

            --skip-post)
                SKIP_POST=1
                ;;

            --root-dir=*)
                ROOT_DIR="${i#*=}"
                ;;

            --data-dir=*)
                DATA_DIR="${i#*=}"
                ;;

            -*)
                ERR_EXIT $ERR_CODE_INVALID_OPTION "invalid option '$i'"
                ;;

            *)
                APP_NAME=$i
                ;;
        esac
    done

    TEMP_DIR="$ROOT_DIR/tmp/appctl"
    mkdir -p "$TEMP_DIR"
    DATA_DIR=${DATA_DIR:-"$ROOT_DIR/var/lib/app/index"}
    LOCK_FILE="$TEMP_DIR/db.lock"
    
    [[ "$(id -u)" != "0" ]] && ERR_EXIT $ERR_CODE_PERMISSION "need superuser access"

    [[ -f "$LOCK_FILE"   ]] && ERR_EXIT $ERR_CODE_EXECUTION "appctl database is locked by $(cat $LOCK_FILE)"

    echo "$APP_NAME" > "$LOCK_FILE" || ERR_EXIT $ERR_CODE_EXECUTION "failed to lock appctl database"

    if ! IsInstalled "$APP_NAME" ; then
        ERR_EXIT $ERR_CODE_INVALID_OPTION "$APP_NAME is not already installed"
    fi


    name=$(grep ^name $DATA_DIR/$APP_NAME/info | awk -F ': ' '{print $2}')
    version=$(grep ^name $DATA_DIR/$APP_NAME/info | awk -F ': ' '{print $2}')
    release=$(grep ^name $DATA_DIR/$APP_NAME/info | awk -F ': ' '{print $2}')

    echo "removing $name"

    rsrv="$TEMP_DIR/$name.rsrv"
    rmv="$TEMP_DIR/$name.rpv"
    rdir="$TEMP_DIR/$name.rdir"
    fls="$TEMP_DIR/$name.fls"

    grep '/$' $DATA_DIR/*/files    \
        | grep -v "$DATA_DIR/$name" \
        | awk -F : '{print $2}'     \
        | sort                      \
        | uniq > "$rsrv"

    grep '/$' $DATA_DIR/$name/files   > "$rmv"
    grep -Fxv -f "$rsrv" "$rmv" | tac > "$rdir"
    grep -v '/$' "$DATA_DIR/$name/files" | tac >> "$fls"

    INFO_MESG "removing $name"

    if [[ ! "$SKIP_PRE" ]] && [[ -f "$DATA_DIR/$name/remove" ]] ; then
        (cd "$ROOT_DIR/"
            bash "$DATA_DIR/$name/remove" "pre" "$name" "$version"
        )
    fi

    (cd "$ROOT_DIR/"
        [[ -s "$fls"  ]] && xargs -a $fls -d'\n' rm
        [[ -s "$rdir" ]] && xargs -a $rdir -d'\n' rmdir
    )

    rm -f "$rsrv" "$rdir" "$rmv" "$fls"

    if [[ ! "$SKIP_POST" ]] && [[ -f "$DATA_DIR/$name/remove" ]] ; then
        (cd "$ROOT_DIR/"
            bash "$DATA_DIR/$name/remove" "post" "$name" "$version"
        )
    fi

    rm -rf "$DATA_DIR/$name"

    if [[ -x "$ROOT_DIR/sbin/ldconfig" ]] ; then
        "$ROOT_DIR/sbin/ldconfig" -r "$ROOT_DIR/"
    fi

    return 0
}

Main $@

cleanup
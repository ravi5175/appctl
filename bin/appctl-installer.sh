#!/bin/bash

ERR_CODE_NOT_EXIST=1500
ERR_CODE_PERMISSION=1501
ERR_CODE_EXECUTION=1502
ERR_CODE_TYPE=1503
ERR_CODE_NOT_DEFINED=1504

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


trap "interrupted" 1 2 3 15

export LC_ALL=C

interrupted() {
    echo
    ERR_EXIT $ERR_CODE_EXECUTION ""
}

function PrintHelp {
cat << EOF
$(basename $0) - part os rlxOS appctl tool to install .rlx package

Usage $(basename $0) [ <options> ] <app.rlx>

Options:
    -u,   --update                  update app
    -r,   --reinstall               reinstall app
    -c,   --ingnore-conflicts       ignore file conflicts
    -v,   --verbose                 print files installed
    -h,   --help                    Print this message
          
          --skip-pre                skip preinstall script before installing/upgrade app
          --skip-post               skip postinstall script after installing/upgrading app

          --no-backup               skip backup when upgrading app
          --root-dir=<path>         install to custom root directory
          --specs=<path>            use custom specifications
          --print-data-dir          print database directory
EOF
}

function IsInstalled {
    [[ -f "$DATA_DIR/$1/info" ]] && return 0 || return 1    
}

function ExecuteScript {
    [[ ! -d "$TEMP_DIR" ]] && mkdir -p "$TEMP_DIR"
    if grep -qx .data/$1 $TEMP_DIR/$name.files ; then
        tar -C "$TEMP_DIR/" -xJf "$PKGNAME" .data/$1
        [[ "$ROOT_DIR" = "/" ]] && EXECUTOR="bash" || EXECUTOR="rlx-chroot $ROOT_DIR"
        
        INFO_MESG "Executing $2 $1 script"
        
        (cd "$ROOT_DIR/"
            $EXECUTOR "$TEMP_DIR/.data/$1" "$2" "$name" "$version"
        )

        rm -f "$TEMP_DIR/.data/$1"
    fi
}

function Main {
    for i in "$@" ; do
        case $i in
            -u|--update)
                UPDATE=1
                ;;
            
            -r|--reinstall)
                REINSTALL=1
                ;;

            -c|--ignore-conflicts)
                IGNORE_CONFLICTS=1
                ;;

            -v|--verbose)
                VERBOSE=1
                ;;
            
            -h|--help)
                PrintHelp
                exit 0
                ;;

            --skip-pre)
                SKIP_PRE=1
                ;;
            
            --skip-post)
                SKIP_POST=1
                ;;
            
            --no-backup)
                NO_BACKUP=1
                ;;

            --root-dir=*)
                ROOT_DIR="${i#*=}"
                ;;
            
            --specs=*)
                SPECS="${i#*=}"
                ;;

            --data-dir=*)
                DATA_DIR="${i#*=}"
                ;;

            --print-data-dir)
                echo "$DATA_DIR"
                exit 0
                ;;

            *.rlx)
                PKGNAME="$(realpath $i)"
                ;;
            
            *)
                ERR_EXIT $ERR_CODE_EXECUTION "Invalid option! ($i)"
                ;;

        esac
    done
    
    TEMP_DIR="$ROOT_DIR/tmp/app/"
    LOCK_FILE="$TEMP_DIR/db.lock"
    DATA_DIR=${DATA_DIR:-"$ROOT_DIR/var/lib/app/index/"}

    source ${SPECS:-"/usr/lib/appctl/specs.sh"}

    
    mkdir -p $TEMP_DIR

    [[ ! -d "$DATA_DIR" ]] && ERR_EXIT $ERR_CODE_NOT_EXIST "appctl database directory not exist $DATA_DIR"
    [[ "$(id -u)" = "0" ]] || ERR_EXIT $ERR_CODE_PERMISSION "$(basename $0): need super user access"
    [[ -f "$LOCK_FILE"  ]] && ERR_EXIT $ERR_CODE_EXECUTION "appctl database is locked by '$(cat $LOCK_FILE)'"
    BASENAME=$(basename $PKGNAME)
    [[ ! -e "$PKGNAME" ]] && ERR_EXIT $ERR_CODE_NOT_EXIST "$PKGNAME not exist"

    tar -C $TEMP_DIR -xJf $PKGNAME .data/info || ERR_EXIT $ERR_CODE_EXECUTION "$PKGNAME is either corrupt or invalid rlx package"
    name=$(cat "$TEMP_DIR/.data/info" | grep ^name: | awk -F ': ' '{print $2}')
    version=$(cat "$TEMP_DIR/.data/info" | grep ^version: | awk -F ': ' '{print $2}')
    release=$(cat "$TEMP_DIR/.data/info" | grep ^release: | awk -F ': ' '{print $2}')

    echo "$name-$version-$release"
    if IsInstalled "$name" ; then
        iver=$(grep ^version: $DATA_DIR/$name/info | awk -F ': ' '{print $2}')
        irel=$(grep ^release: $DATA_DIR/$name/info | awk -F ': ' '{print $2}')
        INSTLD=1
    fi=

    if [[ "$INSTLD" ]] && [[ "$UPDATE" != "1" ]] && [[ "$REINSTALL" != "1" ]] ; then
        echo "$name is already installed"
        cleanup
        exit 112
    fi

    if [[ "$UPDATE" ]] || [[ "$REINSTALL" ]] ; then
        [[ -z $INSTLD ]] && ERR_EXIT $ERR_CODE_EXECUTION "$name is not installed"
    
        [[ ! -z $UPDATE ]] && [[ "$version-$release" = "$iver-$irel" ]] && ERR_EXIT 0 "$name is up-to-date"
    fi

    tar -tJf $PKGNAME > $TEMP_DIR/$name.files 2>/dev/null || ERR_EXIT $ERR_CODE_EXECUTION "$name is corrupted"

    OPER=install

    [[ $UPDATE ]] && OPER=update
    [[ $REINSTALL ]] && OPER=reinstall

    INFO_MESG "${OPER}ing $name"
    
    if [[ -z "$IGNORE_CONFLICTS" ]] ; then
        grep -Ev "^.data*" $TEMP_DIR/$name.files | grep -v '/$' | while read -r line ; do
            [[ "$line" = "${line%.*}.new" ]] && line="${line%.*}"

            if [[ -e "$ROOT_DIR/$line" ]] || [[ -L "$ROOT_DIR/$line" ]] ; then
                if [[ "$UPDATE" ]] || [[ "$REINSTALL" ]] ; then
                    if ! grep -Fqx "$line" "$DATA_DIR/$name/files" ; then
                        echo "$line" >> "$TEMP_DIR/$name.conflicts"
                    fi
                else
                    echo "$line" >> "$TEMP_DIR/$name.conflicts"
                fi
            fi
        done

        [[ -e "$TEMP_DIR/$name.conflicts" ]] && ERR_EXIT $ERR_CODE_EXECUTION "follow files have conflicts  $(cat $TEMP_DIR/$name.conflicts)"
    
    fi

    [[ -z $SKIP_PRE ]] && {
        [[ -z $UPDATE ]] && {
            ExecuteScript "install" "pre"
        } || {
            ExecuteScript "update" "pre"
        }
    }

    for i in $(grep "^.data*" $TEMP_DIR/$name.files) ; do
        exclude_file="$exclude_file --exclude=$i"
    done

    tar --keep-directory-symlink -pxvf "$PKGNAME" -C "$ROOT_DIR"/ $exclude_file | while read -r line ; do
        if [[ "$line" = "${line%.*}.new" ]] ; then
            line="${line%.*}"

            if [[ "$UPDATE" ]] || [[ "$REINSTALL" ]] ; then
                if [[ ! -e "$ROOT_DIR/$line" ]] || [[ "$NO_BACKUP" ]] ; then
                    mv "$ROOT_DIR/$line.new" "$ROOT_DIR/$line.new"
                fi
            else
                mv "$ROOT_DIR/$line.new" "$ROOT_DIR/$line.new"
            fi
        fi
        [[ "$VERBOSE" ]] && echo "extracted $line"
        echo "$line" >> $TEMP_DIR/$name.instld
    done

    if [[ "$UPDATE" ]] || [[ "$REINSTALL" ]] ; then
        rmlst_file="$TEMP_DIR/$name.rmlst_file"
        rmlst_dir="$TEMP_DIR/$name.rmlst_dir"
        rsrv_dir="$TEMP_DIR/$name.rsrv_dir"
        rmlst_all="$TEMP_DIR/$name.rmlst_all"
        grep '/$' $DATA_DIR/*/files             \
            | grep -v $DATA_DIR/$name/.files    \
            | awk -F : '{print $2}'             \
            | sort                              \
            | uniq > $rsrv_dir
        grep -Fxv -f "$TEMP_DIR/$name.instld" $DATA_DIR/*/files > $rmlst_all
        grep -v '/$' "$rmlst_all" | tac > "$rmlst_file"
        grep -Fxv -f "$rsrv_dir" "$rmlst_all" | grep '/$' | tac > "$rmlst_dir"

        (cd "$ROOT_DIR/"
            [[ -s $rmlst_file ]] && xargs -a $rmlst_file -d '\n' rm
            [[ -s $rmlst_dir  ]] && xargs -a $rmlst_dir -d '\n' rmdir
        )

        rm -f "$rmlst_dir" "$rmlst_all" "$rsrv_dir" "$rmlst_file"

    fi

    rm -fr $DATA_DIR/$name
    tar -xJf $PKGNAME .data -C $TEMP_DIR

    mv $TEMP_DIR/.data $DATA_DIR/$name
    
    install -m644 $TEMP_DIR/$name.instld $DATA_DIR/$name/files

    echo -e "\ninstalled: $(date +'%I:%M:%S %p %D:%m:%Y')" >> $DATA_DIR/$name/info

    [[ -z $SKIP_POST ]] && {
        [[ -z $UPDATE ]] && {
            ExecuteScript "install" "post"
        } || {
            ExecuteScript "update" "post"
        }
    }

    if [[ -x "$ROOT_DIR/sbin/ldconfig" ]] ; then
        $ROOT_DIR/sbin/ldconfig -r "$ROOT_DIR/"
    fi
}


Main $@

cleanup

#!/bin/bash

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

SCRIPT="$(realpath "$DIR/../wait-for-files.sh")"

pushd "$DIR"
restore_dir() {
  popd
}
trap restore_dir EXIT

# Function to clean up test files
cleanup() {
    rm -f testfile1 testfile2 testfile3
}

# Function to run a test
run_test() {
    local description="$1"
    shift
    echo "Running test: $description"
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Test failed with status $status"
    else
        echo "Test passed"
    fi
    echo
}

# Clean up any leftover test files
cleanup

# Test waiting for a single file that gets created in time
run_test "Single file, created in time" bash -c "
    touch testfile1 &
    $SCRIPT -f \"testfile1\" -t 5
"
cleanup

# Test waiting for a single file that does not get created in time
run_test "Single file, not created in time" bash -c "
    (sleep 6 && touch testfile1) &
    ! $SCRIPT -f \"testfile1\" -t 5
"
cleanup

# Test waiting for multiple files that all get created in time
run_test "Multiple files, all created in time" bash -c "
    touch testfile1 &
    touch testfile2 &
    $SCRIPT -f \"testfile1 testfile2\" -t 5
"
cleanup

# Test waiting for multiple files where one does not get created in time
run_test "Multiple files, one not created in time" bash -c "
    touch testfile1 &
    (sleep 6 && touch testfile2) &
    ! $SCRIPT -f \"testfile1 testfile2\" -t 5
"
cleanup

# Test waiting for multiple files where none get created in time
run_test "Multiple files, none created in time" bash -c "
    (sleep 6 && touch testfile1) &
    (sleep 6 && touch testfile2) &
    ! $SCRIPT -f \"testfile1 testfile2\" -t 5
"
cleanup

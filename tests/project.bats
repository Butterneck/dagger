setup() {
  load 'helpers'
  common_setup
}

@test "project init, update and info" {
  TEMPDIR=$(mktemp -d)
  TEMPDIR2=$(mktemp -d)
  cd "$TEMPDIR" || exit 1

  "$DAGGER" project init ./ --name "github.com/foo/bar"
  test -d ./cue.mod/pkg
  test -f ./cue.mod/module.cue
  contents=$(cat ./cue.mod/module.cue)
  [ "$contents" == 'module: "github.com/foo/bar"' ]

  echo "ensure old 0.1 style .gitignore is removed:"
  printf "# generated by dagger\ndagger.lock" > .gitignore

  "$DAGGER" project update
  test -d ./cue.mod/pkg/dagger.io
  test -d ./cue.mod/pkg/universe.dagger.io
  test -f ./cue.mod/pkg/.gitattributes
  run cat ./cue.mod/pkg/.gitattributes
  assert_output --partial "generated by dagger"

  test ! -f ./cue.mod/pkg/.gitignore

  run "$DAGGER" project info
  assert_success
  assert_output --partial "Current dagger project in:"
  assert_output --partial "$TEMPDIR"

  cd "$TEMPDIR2" || exit
  run "$DAGGER" project info
  assert_failure
  assert_output --partial "dagger project not found. Run \`dagger project init\`"
}

@test "project init with template" {
  TEMPDIR=$(mktemp -d)
  cd "$TEMPDIR" || exit 1

  if test -f ./hello.cue
  then
    echo "./hello.cue should not exist"
    exit 1
  fi

  run "$DAGGER" project init -t hello

  assert_success

  if test ! -f ./hello.cue
  then
    echo "./hello.cue file was not created by the template flag"
    exit 1
  fi
}

@test "project info list actions" {
  TEMPDIR=$(mktemp -d)
  cd "$TEMPDIR" || exit 1

  run "$DAGGER" project init -t hello
  run "$DAGGER" project update

  run "$DAGGER" project info
  assert_success

  assert_output --partial "ACTION"
  assert_output --partial "hello"

  assert_output --partial "DESCRIPTION"
  assert_output --partial "Hello world"
}

@test "todoapp project with absolute path" {
  TEMPDIR=$(mktemp -d)
  cd "$TEMPDIR" || exit 1

  git clone https://github.com/dagger/todoapp
  cd todoapp || exit 1
  run "$DAGGER" project init
  run "$DAGGER" project update

  run "$DAGGER" -p "$PWD" "do" --help
  assert_success

  cd ~
  run "$DAGGER" -p "$OLDPWD" "do" --help
  assert_success
}

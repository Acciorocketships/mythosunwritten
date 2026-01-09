## Running Tests

In the command line, run `godot-test`, which is aliased to the following command:
`godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json`
This runs the tests a specified in the `gutconfig.json`

## Customising Test Runs

Updates to the gutconfig:

All tests whose filenames match the string in this field will be run.
`selected: ""`

All tests whose function names match the string in this field will be run.
`"unit_test_name" : ""`

## Creating Tests

write a script with `extends GutTest` at the top
in this file, all functions beginning with `test_` will be run
use `assert_true(a)` and `assert_eq(a,b)` to make assertions

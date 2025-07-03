#!/usr/bin/env bash
# str_test.sh - String utility tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(realpath "$SCRIPT_DIR/../../")"

source "$ROOT_DIR/src/lib/str.sh"

pass() { echo "PASS: $1"; }
fail() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    echo -e "FAIL: $desc\n\tEXPECTED: \`$expected\`\n\t  ACTUAL: \`$actual\`\n"
    exit 1
}

test_eq() {
    local desc expected actual input
    desc="$1"
    expected="$2"
    input="$3"
    actual="$4"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        echo -e "INPUT:    \`$input\`"
        fail "$desc" "$expected" "$actual"
    fi
}

# str_trim
test_eq "str_trim trims both ends" "foo bar" "  foo bar  " "$(echo '  foo bar  ' | str_trim)"

# str_to_lower
test_eq "str_to_lower" "foo_bar" "FOO_BAR" "$(echo 'FOO_BAR' | str_to_lower)"

# str_to_upper
test_eq "str_to_upper" "FOO_BAR" "foo_bar" "$(echo 'foo_bar' | str_to_upper)"

# is_snake_case
input="foo_bar"
is_snake_case "$input" && pass "is_snake_case true" || fail "is_snake_case true" "true" "false"
input="FooBar"
! is_snake_case "$input" && pass "is_snake_case false" || fail "is_snake_case false" "false" "true"

# is_screaming_snake_case
input="FOO_BAR"
is_screaming_snake_case "$input" && pass "is_screaming_snake_case true" || fail "is_screaming_snake_case true" "true" "false"
input="foo_bar"
! is_screaming_snake_case "$input" && pass "is_screaming_snake_case false" || fail "is_screaming_snake_case false" "false" "true"

# is_pascal_case
input="FooBar"
is_pascal_case "$input" && pass "is_pascal_case true" || fail "is_pascal_case true" "true" "false"
input="foo_bar"
! is_pascal_case "$input" && pass "is_pascal_case false" || fail "is_pascal_case false" "false" "true"

# is_camel_case
input="fooBar"
is_camel_case "$input" && pass "is_camel_case true" || fail "is_camel_case true" "true" "false"
input="FooBar"
! is_camel_case "$input" && pass "is_camel_case false" || fail "is_camel_case false" "false" "true"

# is_kebab_case
input="foo-bar"
is_kebab_case "$input" && pass "is_kebab_case true" || fail "is_kebab_case true" "true" "false"
input="foo_Bar"
! is_kebab_case "$input" && pass "is_kebab_case false" || fail "is_kebab_case false" "false" "true"

# is_title_case
input="Foo Bar"
is_title_case "$input" && pass "is_title_case true" || fail "is_title_case true" "true" "false"
input="foo bar"
! is_title_case "$input" && pass "is_title_case false" || fail "is_title_case false" "false" "true"

# str_to_camel_case
test_eq "str_to_camel_case snake" "fooBar" "foo_bar" "$(str_to_camel_case foo_bar)"
test_eq "str_to_camel_case kebab" "fooBar" "foo-bar" "$(str_to_camel_case foo-bar)"
test_eq "str_to_camel_case screaming" "fooBar" "FOO_BAR" "$(str_to_camel_case FOO_BAR)"
test_eq "str_to_camel_case pascal" "fooBar" "FooBar" "$(str_to_camel_case FooBar)"

# str_to_pascal_case
test_eq "str_to_pascal_case snake" "FooBar" "foo_bar" "$(str_to_pascal_case foo_bar)"
test_eq "str_to_pascal_case kebab" "FooBar" "foo-bar" "$(str_to_pascal_case foo-bar)"
test_eq "str_to_pascal_case screaming" "FooBar" "FOO_BAR" "$(str_to_pascal_case FOO_BAR)"
test_eq "str_to_pascal_case camel" "FooBar" "fooBar" "$(str_to_pascal_case fooBar)"

# str_to_screaming_snake_case
test_eq "str_to_screaming_snake_case snake" "FOO_BAR" "foo_bar" "$(str_to_screaming_snake_case foo_bar)"
test_eq "str_to_screaming_snake_case kebab" "FOO_BAR" "foo-bar" "$(str_to_screaming_snake_case foo-bar)"
test_eq "str_to_screaming_snake_case camel" "FOO_BAR" "fooBar" "$(str_to_screaming_snake_case fooBar)"
test_eq "str_to_screaming_snake_case pascal" "FOO_BAR" "FooBar" "$(str_to_screaming_snake_case FooBar)"

# str_to_snake_case
test_eq "str_to_snake_case camel" "foo_bar" "fooBar" "$(str_to_snake_case fooBar)"
test_eq "str_to_snake_case pascal" "foo_bar" "FooBar" "$(str_to_snake_case FooBar)"
test_eq "str_to_snake_case kebab" "foo_bar" "foo-bar" "$(str_to_snake_case foo-bar)"

# str_to_kebab_case
test_eq "str_to_kebab_case camel" "foo-bar" "fooBar" "$(str_to_kebab_case fooBar)"
test_eq "str_to_kebab_case pascal" "foo-bar" "FooBar" "$(str_to_kebab_case FooBar)"
test_eq "str_to_kebab_case snake" "foo-bar" "foo_bar" "$(str_to_kebab_case foo_bar)"

# str_to_title_case
test_eq "str_to_title_case snake" "Foo Bar" "foo_bar" "$(str_to_title_case foo_bar)"
test_eq "str_to_title_case kebab" "Foo Bar" "foo-bar" "$(str_to_title_case foo-bar)"
test_eq "str_to_title_case screaming" "Foo Bar" "FOO_BAR" "$(str_to_title_case FOO_BAR)"
test_eq "str_to_title_case camel" "Foo Bar" "fooBar" "$(str_to_title_case fooBar)"

# Edge and malformed input tests

# is_snake_case edge cases
test_eq "is_snake_case empty" "false" "" "$(is_snake_case "" && echo true || echo false)"
test_eq "is_snake_case leading underscore" "false" "_foo_bar" "$(is_snake_case "_foo_bar" && echo true || echo false)"
test_eq "is_snake_case trailing underscore" "false" "foo_bar_" "$(is_snake_case "foo_bar_" && echo true || echo false)"
test_eq "is_snake_case double underscore" "false" "foo__bar" "$(is_snake_case "foo__bar" && echo true || echo false)"
test_eq "is_snake_case single word" "false" "foo" "$(is_snake_case "foo" && echo true || echo false)"
test_eq "is_snake_case with digits" "true" "foo1_bar2" "$(is_snake_case "foo1_bar2" && echo true || echo false)"

# is_screaming_snake_case edge cases
test_eq "is_screaming_snake_case empty" "false" "" "$(is_screaming_snake_case "" && echo true || echo false)"
test_eq "is_screaming_snake_case leading underscore" "false" "_FOO_BAR" "$(is_screaming_snake_case "_FOO_BAR" && echo true || echo false)"
test_eq "is_screaming_snake_case trailing underscore" "false" "FOO_BAR_" "$(is_screaming_snake_case "FOO_BAR_" && echo true || echo false)"
test_eq "is_screaming_snake_case double underscore" "false" "FOO__BAR" "$(is_screaming_snake_case "FOO__BAR" && echo true || echo false)"
test_eq "is_screaming_snake_case single word" "false" "FOO" "$(is_screaming_snake_case "FOO" && echo true || echo false)"
test_eq "is_screaming_snake_case with digits" "true" "FOO1_BAR2" "$(is_screaming_snake_case "FOO1_BAR2" && echo true || echo false)"

# is_kebab_case edge cases
test_eq "is_kebab_case empty" "false" "" "$(is_kebab_case "" && echo true || echo false)"
test_eq "is_kebab_case leading hyphen" "false" "-foo-bar" "$(is_kebab_case "-foo-bar" && echo true || echo false)"
test_eq "is_kebab_case trailing hyphen" "false" "foo-bar-" "$(is_kebab_case "foo-bar-" && echo true || echo false)"
test_eq "is_kebab_case double hyphen" "false" "foo--bar" "$(is_kebab_case "foo--bar" && echo true || echo false)"
test_eq "is_kebab_case single word" "false" "foo" "$(is_kebab_case "foo" && echo true || echo false)"
test_eq "is_kebab_case with digits" "true" "foo1-bar2" "$(is_kebab_case "foo1-bar2" && echo true || echo false)"

# is_pascal_case edge cases
test_eq "is_pascal_case empty" "false" "" "$(is_pascal_case "" && echo true || echo false)"
test_eq "is_pascal_case single word" "true" "Foobar" "$(is_pascal_case "Foobar" && echo true || echo false)"
test_eq "is_pascal_case with digit" "true" "FooBar1" "$(is_pascal_case "FooBar1" && echo true || echo false)"
test_eq "is_pascal_case with underscore" "false" "Foo_Bar" "$(is_pascal_case "Foo_Bar" && echo true || echo false)"

# is_camel_case edge cases
test_eq "is_camel_case empty" "false" "" "$(is_camel_case "" && echo true || echo false)"
test_eq "is_camel_case single word" "true" "foobar" "$(is_camel_case "foobar" && echo true || echo false)"
test_eq "is_camel_case with digit" "true" "fooBar1" "$(is_camel_case "fooBar1" && echo true || echo false)"
test_eq "is_camel_case with underscore" "false" "foo_Bar" "$(is_camel_case "foo_Bar" && echo true || echo false)"

# is_title_case edge cases
test_eq "is_title_case empty" "false" "" "$(is_title_case "" && echo true || echo false)"
test_eq "is_title_case single word" "true" "Foo" "$(is_title_case "Foo" && echo true || echo false)"
test_eq "is_title_case with digit" "true" "Foo Bar1" "$(is_title_case "Foo Bar1" && echo true || echo false)"
test_eq "is_title_case mixed case" "false" "Foo bar" "$(is_title_case "Foo bar" && echo true || echo false)"

# Additional edge cases

test_eq "is_snake_case whitespace only" "false" "   " "$(is_snake_case "   " && echo true || echo false)"
test_eq "is_snake_case special chars" "false" "foo@bar" "$(is_snake_case "foo@bar" && echo true || echo false)"
test_eq "is_snake_case numbers only" "false" "12345" "$(is_snake_case "12345" && echo true || echo false)"
test_eq "is_kebab_case mixed delimiters" "false" "foo_bar-baz" "$(is_kebab_case "foo_bar-baz" && echo true || echo false)"
test_eq "is_kebab_case all uppercase" "false" "FOO-BAR" "$(is_kebab_case "FOO-BAR" && echo true || echo false)"
test_eq "is_pascal_case non-ascii" "false" "FööBar" "$(is_pascal_case "FööBar" && echo true || echo false)"
test_eq "is_title_case emoji" "false" "Foo 😀 Bar" "$(is_title_case "Foo 😀 Bar" && echo true || echo false)"
test_eq "is_screaming_snake_case very long" "true" "$(printf 'A%.0s' {1..100})_BAR" "$(is_screaming_snake_case "$(printf 'A%.0s' {1..100})_BAR" && echo true || echo false)"
test_eq "is_snake_case alternating delimiters" "false" "foo_bar-baz" "$(is_snake_case "foo_bar-baz" && echo true || echo false)"
test_eq "is_snake_case tabs and newlines" "false" "foo\tbar\nbaz" "$(is_snake_case $'foo\tbar\nbaz' && echo true || echo false)"

echo "All tests passed."

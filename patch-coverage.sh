#!/bin/sh

# Run this script from build directory:
# git checkout gh911
# meson -Db_coverage=true -Dbuild-api-tests=false build
# cd build
# ninja
# meson test -t 3
# ninja coverage-xml

print_filename=0

function skip_line {
    line=$1
    [[ "${#line}" -eq 0 || "${line[@]:0:2}" = "//" || "${line[@]:0:2}" = "/*" || "${line[@]:0:2}" = "*/" ||"$line" =~ "#endif" || 
        "$line" =~ "#if" || "$line" = "}" ]]
}

function check_coverage {
    failed=0
    git diff master | grep "^+" > lines-to-verify.patch

    while read line;
    do
        if [[ "${line[@]:0:6}" = '+++ b/' ]];
        then
            # This line contains name of a file that was changed
            filepath="${line[@]:6}"
            filename="${filepath##*/}"
            fileext="${filepath##*.}"

            # Skip all files that don't have `.c` extension or are not under src
            # directory
            if [[ "$fileext" != "c" && "${line[@]:0:3}" != "src" ]]; then
                skip_to_next_file=1
                continue
            else
                skip_to_next_file=0
                print_filename=1
            fi

            # TODO: How to handle files with same name ?
            gcda_file=$(find . -name "*.gcda" |  grep "$filename")
            gcov "$gcda_file" > /dev/null 2>&1
            gcov_file="$filename.gcov"
        else
            if [[ $skip_to_next_file -eq 1 ]]; then
                continue
            fi

            if [[ ! -e "$gcov_file" ]];
            then
                continue
            fi
            # We are reading a line that was either added or modified
            # Strip leading `+` sign and spaces
            original_line="$line"
            line=$(echo "$line" | tr -d '^+')
            line=$(echo "$line" | sed -e 's/^[[:space:]]*//')

            # Skip empty lines, comments and macro keywords
            if skip_line "$line"
            then
                continue
            fi

            # All lines that contain`#####:` in coverage report are not covered by tests
            grep '#####:' "$gcov_file" | grep -Fq "$line"

            if [[ $? -eq 0 ]]; then
                if [[ "$failed" -eq 0 ]]; then
                    failed=1
                    echo "These lines from requested patch are not covered by tests: "
                fi
                # Print filename before first line of file that's not covered by tests
                if [[ "$print_filename" -eq 1 ]];
                then
                    echo "$filepath: "
                    print_filename=0
               fi

                echo "$original_line"
            fi
        fi
    done < lines-to-verify.patch
    return $failed
}

check_coverage

# if [[ $? -eq 0 ]]; then
#     ix_url=""
#     state="success"
#     description="Build passed"
# else
#     # ix_url=$(echo "$out" | curl -F 'f:1=<-' ix.io)
#     echo $out
#     state="failure"
#     description="Build failed"
# fi
#
# echo $ix_url

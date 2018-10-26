#!/bin/sh
set -ex

if [[ ! -d ast ]]
then
    git clone git@github.com:att/ast.git
    cd ast
    git remote add kshbugbot git@github.com-kshbugbot:kshbugbot/ast.git
    git config user.name "kshbugbot"
    git config user.email "kshbugbot@gmail.com" 
else
    cd ast
    git reset --hard
    git checkout master
    git pull origin master
fi

bin/style all
lines_changed=$(git diff | wc -l)

if [[ "$lines_changed" -gt 0 ]]
then
    base="master"
    git branch -D fix-styling || :
    git checkout -b fix-styling
    git commit -a -m "[kshbugbot] Fix code styling"
    git push --force kshbugbot fix-styling
    title="[kshbugbot] Fix code styling"
    head="kshbugbot:fix-styling"
    # Open a pull request
    curl -s --user $GITHUB_USER:$GITHUB_API_KEY -X POST --data "{\"title\": \"$title\", \"head\": \"$head\", \"base\": \"$base\" }" "https://api.github.com/repos/att/ast/pulls"
else
    echo "All files are correctly styled"
fi

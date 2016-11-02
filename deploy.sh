#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

SOURCE_BRANCH="src"
TARGET_BRANCH="master"

function doCompile {
  $GOPATH/bin/hugo -d ./public
}

git fetch origin $SOURCE_BRANCH
git -C ./public reset --hard FETCH_HEAD
git clean -df


# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy; just doing a build."
    doCompile
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing gh-pages for this repo into public/
git clone -b $TARGET_BRANCH $REPO public || git -C ./ fetch origin $TARGET_BRANCH
git -C ./public reset --hard FETCH_HEAD
git clean -df

# Clean out existing contents
rm -rf ./public/* || true

# Run our compile script
doCompile

# Now let's go have some fun with the cloned repo
git -C ./public config user.name "Travis CI"
git -C ./public config user.email "$COMMIT_AUTHOR_EMAIL"
git -C ./public add --all
# If there is nothing to commit, exit
git -C ./public commit -m "Deploy to GitHub Pages: ${SHA}" || exit 0

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in deploy_key.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key

# Now that we're all set up, we can push.
git -C ./public push $SSH_REPO $TARGET_BRANCH

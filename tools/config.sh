#!/bin/bash


if [ -z $IDF_PATH ]; then
    export IDF_PATH="$PWD/esp-idf"
fi

if [ -z $IDF_BRANCH ]; then
    IDF_BRANCH="release/v5.1"
fi

# Arduino branch to use
if [ -z $AR_BRANCH ]; then
    AR_BRANCH="main"
fi

if [ -z $IDF_TARGET ]; then
    if [ -f sdkconfig ]; then
        IDF_TARGET=`cat sdkconfig | grep CONFIG_IDF_TARGET= | cut -d'"' -f2`
        if [ "$IDF_TARGET" = "" ]; then
            IDF_TARGET="esp32"
        fi
    else
        IDF_TARGET="esp32"
    fi
fi

# Owner of the target ESP32 Arduino repository
AR_USER="tasmota"

# IDF commit to use
#IDF_COMMIT=""

# Arduino commit to use
#AR_COMMIT=""

# The full name of the repository
AR_REPO="$AR_USER/arduino-esp32"
IDF_REPO="$AR_USER/esp-idf"
AR_LIBS_REPO="$AR_USER/esp32-arduino-libs"

AR_REPO_URL="https://github.com/$AR_REPO.git"
IDF_REPO_URL="https://github.com/$IDF_REPO.git"
AR_LIBS_REPO_URL="https://github.com/$AR_LIBS_REPO.git"
if [ -n $GITHUB_TOKEN ]; then
    AR_REPO_URL="https://$GITHUB_TOKEN@github.com/$AR_REPO.git"
    AR_LIBS_REPO_URL="https://$GITHUB_TOKEN@github.com/$AR_LIBS_REPO.git"
fi

AR_ROOT="$PWD"
AR_COMPS="$AR_ROOT/components"
AR_MANAGED_COMPS="$AR_ROOT/managed_components"
AR_OUT="$AR_ROOT/out"
AR_TOOLS="$AR_OUT/tools"
AR_PLATFORM_TXT="$AR_OUT/platform.txt"
AR_GEN_PART_PY="$AR_TOOLS/gen_esp32part.py"
AR_SDK="$AR_TOOLS/esp32-arduino-libs/$IDF_TARGET"
PIO_SDK="FRAMEWORK_SDK_DIR, \"$IDF_TARGET\""
TOOLS_JSON_OUT="$AR_TOOLS/esp32-arduino-libs"
IDF_LIBS_DIR="$AR_ROOT/../esp32-arduino-libs"

if [ "$IDF_COMMIT" ]; then
    	echo "Using IDF commit $IDF_COMMIT"
	export IDF_COMMIT
elif [ -d "$IDF_PATH" ]; then
	export IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
	export IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)
fi

if [ "$AR_COMMIT" ]; then
    echo "Using commit $AR_COMMIT for Arduino"
else
    AR_COMMIT=$(git -C "$AR_COMPS/arduino" rev-parse --short HEAD || echo "")
fi

#rm -rf release-info.txt
#echo "Framework built from Tasmota IDF branch $IDF_BRANCH commit $IDF_COMMIT and $AR_REPO branch $AR_BRANCH commit $AR_COMMIT" >> release-info.txt

function get_os(){
    OSBITS=`arch`
    if [[ "$OSTYPE" == "linux"* ]]; then
        if [[ "$OSBITS" == "i686" ]]; then
            echo "linux32"
        elif [[ "$OSBITS" == "x86_64" ]]; then
            echo "linux64"
        elif [[ "$OSBITS" == "armv7l" ]]; then
            echo "linux-armel"
        else
            echo "unknown"
            return 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "win32"
    else
        echo "$OSTYPE"
        return 1
    fi
    return 0
}

AR_OS=`get_os`

export SED="sed"
export SSTAT="stat -c %s"

if [[ "$AR_OS" == "macos" ]]; then
    if ! [ -x "$(command -v gsed)" ]; then
        echo "ERROR: gsed is not installed! Please install gsed first. ex. brew install gsed"
        exit 1
    fi
    if ! [ -x "$(command -v gawk)" ]; then
        echo "ERROR: gawk is not installed! Please install gawk first. ex. brew install gawk"
        exit 1
    fi
    export SED="gsed"
    export SSTAT="stat -f %z"
fi

function github_commit_exists(){ #github_commit_exists <repo-path> <branch-name> <commit-message>
    local repo_path="$1"
    local branch_name="$2"
    local commit_message="$3"
    local commits_found=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/commits?sha=$branch_name" | jq -r '.[].commit.message' | grep "$commit_message" | wc -l`
    if [ ! "$commits_found" == "" ] && [ ! "$commits_found" == "null" ] && [ ! "$commits_found" == "0" ]; then echo $commits_found; else echo 0; fi
}

function github_last_commit(){ # github_last_commit <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local commit=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/commits/heads/$branch_name" | jq -r '.sha'`
    if [ ! "$commit" == "" ] && [ ! "$commit" == "null" ]; then
        echo ${commit:0:8}
    else
        echo ""
    fi
}

function github_branch_exists(){ # github_branch_exists <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local branch=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/branches/$branch_name" | jq -r '.name'`
    if [ "$branch" == "$branch_name" ]; then echo 1; else echo 0; fi
}

function github_pr_exists(){ # github_pr_exists <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local pr_num=`curl -s -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" "https://api.github.com/repos/$repo_path/pulls?head=$AR_USER:$branch_name&state=open" | jq -r '.[].number'`
    if [ ! "$pr_num" == "" ] && [ ! "$pr_num" == "null" ]; then echo 1; else echo 0; fi
}



function git_branch_exists(){ # git_branch_exists <repo-path> <branch-name>
    local repo_path="$1"
    local branch_name="$2"
    local branch_found=`git -C "$repo_path" ls-remote --heads origin "$branch_name"`
    if [ -n "$branch_found" ]; then echo 1; else echo 0; fi
}

function git_commit_exists(){ #git_commit_exists <repo-path> <commit-message>
    local repo_path="$1"
    local commit_message="$2"
    local commits_found=`git -C "$repo_path" log --all --grep="$commit_message" | grep commit`
    if [ -n "$commits_found" ]; then echo 1; else echo 0; fi
}

function git_create_pr(){ # git_create_pr <branch> <title>
    local pr_branch="$1"
    local pr_title="$2"
    local pr_target="$3"
    local pr_body="\`\`\`\r\n"
    while read -r line; do pr_body+=$line"\r\n"; done < "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    pr_body+="\`\`\`\r\n"
    local pr_data="{\"title\": \"$pr_title\", \"body\": \"$pr_body\", \"head\": \"$AR_USER:$pr_branch\", \"base\": \"$pr_target\"}"
    git_create_pr_res=`echo "$pr_data" | curl -k -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw+json" --data @- "https://api.github.com/repos/$AR_REPO/pulls"`
    local done_pr=`echo "$git_create_pr_res" | jq -r '.title'`
    if [ ! "$done_pr" == "" ] && [ ! "$done_pr" == "null" ]; then echo 1; else echo 0; fi
}

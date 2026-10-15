#!/usr/bin/env bash
# Builds V at a pinned commit, bootstrapped from a pinned vc snapshot.
#
#   build-v.sh <dir> <v_ref> <vc_ref>
#
# Shared by the CI image (Containerfile) and the GitHub mirror's release
# workflow, so every lilly build -- CI, forge releases, macOS releases --
# compiles with the same V.
#
# Why vc is pinned too: V's `make` bootstraps from vlang/vc, the generated C
# of a recent V, and always pulls the latest snapshot. A pinned V source then
# drifts away from the compiler that has to build it, until a newer snapshot
# rejects syntax the older source still uses. That broke the daily image
# build from 2026-10-07 (vlib/math/bits/bits.v: "the condition of an `if`
# cannot start with a parenthesized `if` expression").
#
# To bump V, set V_REF and VC_REF together in the Containerfile. VC_REF is
# the newest vlang/vc commit whose "[v:master] <sha>" subject names an
# ancestor of V_REF: an older bootstrap compiler builds newer source, which
# is the direction V's own bootstrap relies on, but not the reverse.
set -euo pipefail

if [ $# -ne 3 ]; then
	echo "usage: $0 <dir> <v_ref> <vc_ref>" >&2
	exit 2
fi
dir=$1
v_ref=$2
vc_ref=$3

# A ref rather than a clone of master, so this takes either a SHA or a branch
# name. Shallow, since the history is never needed and is most of the fetch.
git init --quiet "$dir"
cd "$dir"
git remote add origin https://github.com/vlang/v
git fetch --depth=1 origin "$v_ref"
git checkout --quiet --detach FETCH_HEAD

# The bundled TCC is fetched as `make` normally would. It is not pinned: the
# prebuilt bundle is versioned separately and has not been a source of skew.
make latest_tcc

# local=1 makes `make` build from the vc already in place instead of pulling
# the latest one. It also skips fetching TCC, hence the step above.
git clone --filter=blob:none --quiet https://github.com/vlang/vc vc
git -C vc checkout --quiet --detach "$vc_ref"
make local=1

./v version

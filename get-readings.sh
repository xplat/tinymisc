#!/bin/sh

# if you don't have git-annex or it's having trouble with some downloads, use
# this handy script instead.

set -e

cd readings

updated=no

if git rev-parse --verify -q git-annex >/dev/null; then
  :
  # git-annex metadata already set up
elif which git-annex >/dev/null; then
  # get git-annex to do the setup itself, safest
  git-annex init
else
  # make sure the git-annex branch is getting pulled
  # XXX i hope you called upstream 'origin' -- how can i autosense this?
  git branch --track git-annex origin/git-annex
fi

for i in *; do
  link="$(git cat-file blob :readings/"$i")"
  if [ -f "$link" ]; then
    :
    # nothing to do
  else
    key="$(basename -- "$link")"
    hash="$(echo -n "$key" | md5sum)"
    url="$(git cat-file blob "git-annex:$(echo "$hash" | cut -c -3)/$(echo "$hash" | cut -c 4-6)/$key.log.web" | grep '^[^ ]\+ 1 ' | tail -n 1 | sed -e 's/^[^ ]\+ 1 //')"
    mkdir -p ../.git/annex/tmp
    tpath="../.git/annex/tmp/$key"
    if curl -fgL -o "$tpath" "$url"; then
      checkkey="SHA256-s$(find "$tpath" -printf "%s")--$(sha256sum "$tpath" | cut -c -64)"
      if [ "$checkkey" == "$key" ]; then
        # success
        mkdir -p "$(dirname "$link")"
        mv -n -- "$tpath" "$link"
        chmod 0444 "$link"
        chmod 0555 "$(dirname "$link")"
        updated=yes
      else
        echo "FAILED: content of '$url' did not match stored hash and size of '$i'"
      fi
    else
      echo "FAILED: couldn't get '$i' at '$url'"
    fi
  fi
done

if [ "$updated" = yes ]; then
  if which git-annex >/dev/null; then
    git-annex fsck
  fi
fi

echo "done."
